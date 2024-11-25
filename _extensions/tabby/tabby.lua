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
local document_metadata = {}

-- Helper function to get language from code block
---@param block CodeBlock The code block to extract language from
---@return string language The programming language of the code block, defaults to "text"
local function get_language(block)
    return block.attr.classes[1] or "text"
end

-- Helper function to create a tab label from language
---@param lang string The programming language identifier
---@return string label The formatted label with first letter capitalized
local function create_tab_label(lang)
    quarto.log.debug("Creating tab label for language: " .. lang)
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
---@param code_blocks CodeBlock[] List of code blocks to search
---@param default_lang string|nil The default language to find
---@return number index The index of the default language (1-based), returns 1 if not found
local function find_default_tab_index(code_blocks, default_lang)
    if not default_lang then
        return 1
    end
    
    default_lang = default_lang:lower()
    
    for i, block in ipairs(code_blocks) do
        local lang = get_language(block):lower()
        if lang == default_lang then
            return i
        end
    end
    
    return 1
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
    document_metadata = meta
    return meta
end

-- Process div elements to create tabsets for code blocks under the 'tabby' class
---@return table processed_div The processed div element
function Div(div)
    -- Only process divs with class 'tabby'
    if not div.classes:includes('tabby') then
        return div
    end

    -- Find all code blocks and other content within the div
    ---@type CodeBlock[]
    local code_blocks = {}
    ---@type pandoc.List
    local other_content = pandoc.List()
    
    for _, block in ipairs(div.content) do
        if block.t == 'CodeBlock' then
            table.insert(code_blocks, block)
        else
            other_content:insert(block)
        end
    end

    -- If no code blocks found, return original div
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
    
    -- Create tabs for each code block
    ---@type table[]
    local tabs = {}
    for i, code_block in ipairs(code_blocks) do
        local lang = get_language(code_block)
        local tab = quarto.Tab({
            title = create_tab_label(lang),
            content = pandoc.Blocks({code_block}),
            active = (i == default_index)
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
    Meta = Meta,
    Div = Div
}