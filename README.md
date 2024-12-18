> [!IMPORTANT]
>
> This extension may change further as it is developed. Please check back for updates.

# Tabby - Automatic Code Tabsets for Quarto <img src="https://github.com/user-attachments/assets/2b293570-727a-4ca2-85e6-0c308108772a" align ="right" alt="Logo: A tabby cat sitting ontop of tabs." width ="150"/>

Tabby is a Quarto extension that automatically creates tabsets for code blocks, making it easy to present multiple programming language implementations side by side. It leverages Quarto's Tabset API to create an integrated tabbing experience.

## Installation

To install Tabby, run the following command in your project directory:

```bash
quarto add coatless-quarto/tabby
```

This will install the extension under the `_extensions` subdirectory. If you're using version control, you will want to check in this directory.

## Usage

### Setup

Add the filter to your document's YAML header or your project's `_quarto.yml` file:

```yaml
filters:
  - tabby
```

### Automatic Tabsets

Create a tabset by wrapping code blocks in a div with the `tabby` class:

````markdown
::: {.tabby}
```{python}
print("Hello, World!")
```

```javascript
console.log("Hello, World!");
```

```{r}
print("Hello, World!")
```
:::
````

This will automatically create a tabset with three tabs: "Python", "Javascript", and "R", each containing the respective code and, where applicable, its output.

### Default Tab Selection

You can set the default selected tab in three ways, listed in order of precedence (highest to lowest):

1. **URL Parameter** - Add `?default-tab=python` to your URL
   ```
   https://example.com/document.html?default-tab=python
   ```

2. **Individual Tabset** - Use div attributes:
   ```markdown
   ::: {.tabby default-tab="javascript"}
   ...
   :::
   ```

3. **Document Level** - Set in YAML frontmatter:
   ```yaml
   tabby:
     default-tab: python
   ```

### Tab Groups

Synchronize tab selection across multiple tabsets using the `group` attribute, similar to [Quarto Tabsets](https://quarto.org/docs/output-formats/html-basics.html#tabset-groups):

````markdown
::: {.tabby group="mygroup"}
```python
def greet():
    print("Hello!")
```

```javascript
function greet() {
    console.log("Hello!");
}
```
:::

Some text in between...

::: {.tabby group="mygroup"}
```python
greet()
```

```javascript
greet();
```
:::
````

When you switch tabs in one tabset, all tabsets in the same group will switch to the same language.

## Configuration Options

| Option | Description | Default | Example |
|--------|-------------|---------|----------|
| `default-tab` | Sets the default selected tab | `1` | `python`, `r`, `javascript` |
| `group` | Groups tabs across multiple tabsets | `null` | `"mygroup"` |

Configure options in your document's YAML frontmatter:

```yaml
tabby:
  default-tab: python    # Default tab selection
```
