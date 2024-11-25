-- Define these classes to avoid warnings
---@class Block
---@field t string The type of the block
---@field attr table Block attributes
---@field content? table Block content

---@class Attr
---@field classes table List of classes
---@field attributes table<string, string> Key-value attributes

---@class CodeBlock : Block
---@field attr Attr Block attributes including classes and other metadata

---@class DocumentMetadata
---@field tabby? table<string, any> Configuration options for tabby
---@field tabby_url_handler_added? boolean Flag indicating if URL handler was added

-- Store metadata at the module level
---@type DocumentMetadata
local document_metadata = {
    tabby = {},
    tabby_url_handler_added = false
}

-- Helper function to get language from code block or cell
---@param block Block The block to extract language from
---@return string language The programming language, defaults to "text"
local function get_language(block)
    if block.t == 'CodeBlock' then
        return block.attr.classes[1] or "text"
    elseif block.t == 'Div' and block.classes:includes('cell') then
        -- Find the first code block in the cell and get its language
        for _, content in ipairs(block.content) do
            if content.t == 'CodeBlock' and content.attr.classes[1] then
                return content.attr.classes[1]
            end
        end
    end
    return "text"
end

-- Helper function to create a tab label from language
---@param lang string The programming language identifier
---@return string label The formatted label with first letter capitalized
local function create_tab_label(lang)
    local label = lang:gsub("^%l", string.upper)
    return label
end

-- Helper function to get default language from metadata or local setting
---@param local_default string|nil The local default language setting
---@return string|nil default_lang The determined default language
local function get_default_language(local_default)
    if local_default then
        return local_default
    end
    
    if document_metadata.tabby and document_metadata.tabby["default-tab"] then
        return document_metadata.tabby["default-tab"]
    end
    
    return nil
end

-- Helper function to find index of default language
---@param blocks Block[] List of blocks to search
---@param default_lang string|nil The default language to find
---@return number index The index of the default language (1-based), returns 1 if not found
local function find_default_tab_index(blocks, default_lang)
    if not default_lang then
        return 1
    end
    
    default_lang = default_lang:lower()
    
    for i, block in ipairs(blocks) do
        local lang = get_language(block):lower()
        if lang == default_lang then
            return i
        end
    end
    
    return 1
end

-- Helper function to reorder tabs so default is first
---@param blocks Block[] List of blocks to arrange
---@param default_index number The 1-based index of the default tab
---@return Block[] reordered_blocks The reordered blocks
local function reorder_for_default(blocks, default_index)
    if default_index == 1 then
        return blocks
    end
    
    local result = {}
    -- First add the default block
    table.insert(result, blocks[default_index])
    
    -- Then add all other blocks in their original order
    for i, block in ipairs(blocks) do
        if i ~= default_index then
            table.insert(result, block)
        end
    end
    
    return result
end

-- Create URL handler JavaScript as a raw block
---@return table raw_block A pandoc RawBlock containing the JavaScript URL handler
local function create_url_handler()
    return pandoc.RawBlock('html', [[
<script>
document.addEventListener('DOMContentLoaded', function() {
    // Get default-tab from URL if present
    const urlParams = new URLSearchParams(window.location.search);
    const defaultTab = urlParams.get('default-tab');
    
    if (defaultTab) {
        const tabName = defaultTab.toLowerCase();
        // Find all tab buttons
        document.querySelectorAll('[role="tab"]').forEach(button => {
            if (button.textContent.toLowerCase() === tabName) {
                button.click();
            }
        });
    }
});
</script>
]])
end

-- Load metadata and store it at the module level
---@return table meta The processed metadata
function Meta(meta)
    if meta and meta.tabby then
        -- Copy all key-value pairs using a loop
        for key, value in pairs(meta.tabby) do
            document_metadata.tabby[key] = pandoc.utils.stringify(value)
        end
    end
    return meta
end

-- Process div elements to create tabsets for code blocks and cells under the 'tabby' class
---@return table processed_div The processed div element
function Div(div)
    -- Only process divs with class 'tabby'
    if not div.classes:includes('tabby') then
        return div
    end

    -- Find all code blocks, cells, and other content within the div
    ---@type Block[]
    local code_blocks = {}
    ---@type pandoc.List
    local other_content = pandoc.List()
    
    for _, block in ipairs(div.content) do
        if block.t == 'CodeBlock' or (block.t == 'Div' and block.classes:includes('cell')) then
            table.insert(code_blocks, block)
        else
            other_content:insert(block)
        end
    end

    -- If no code blocks or cells found, return original div
    if #code_blocks == 0 then
        return div
    end

    -- Get attributes
    local group_attr = div.attr.attributes["group"]
    local local_default = div.attr.attributes["default-tab"]
    
    -- Get default language
    local default_lang = get_default_language(local_default)

    -- Find the index of the default tab
    local default_index = find_default_tab_index(code_blocks, default_lang)

    -- Reorder blocks so default is first
    local ordered_blocks = reorder_for_default(code_blocks, default_index)
    
    -- Create tabs for each block
    ---@type table[]
    local tabs = {}
    for _, block in ipairs(ordered_blocks) do
        local lang = get_language(block)
        local tab = quarto.Tab({
            title = create_tab_label(lang),
            content = pandoc.Blocks({block})
        })
        table.insert(tabs, tab)
    end

    -- Prepare attributes for the tabset
    ---@type table<string, string>
    local tabset_attrs = {
        class = "tabby-group"
    }
    
    if group_attr then
        tabset_attrs["group"] = group_attr
    end
    
    if default_lang then
        tabset_attrs["default-tab"] = default_lang
    end

    -- Create the tabset
    local tabset_raw, _ = quarto.Tabset({
        level = 3,
        tabs = tabs,
        attr = pandoc.Attr("", {"panel-tabset"}, tabset_attrs)
    })

    -- Create final content
    local final_content = pandoc.List()

    final_content:extend(other_content)
    final_content:insert(tabset_raw)
    
    -- Add URL handler script only once
    if not document_metadata.tabby_url_handler_added then
        final_content:insert(create_url_handler())
        document_metadata.tabby_url_handler_added = true
    end

    return pandoc.Div(final_content)
end

-- Return the list of functions to register
---@type table<string, function>
return {
    {Meta = Meta},
    {Div = Div}
}