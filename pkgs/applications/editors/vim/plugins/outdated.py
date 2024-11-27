import os
import re
from datetime import datetime


def parse_plugins(file_path):
    with open(file_path, 'r') as file:
        content = file.read()

    # Regex to find plugin details
    plugin_pattern = re.compile(r'(\w+)\s*=\s*buildVimPlugin\s*{\s*pname\s*=\s*"([^"]+)";\s*version\s*=\s*"([^"]+)";', re.MULTILINE)
    plugins = plugin_pattern.findall(content)

    outdated_plugins = []
    current_year = datetime.now().year

    for plugin in plugins:
        name, pname, version = plugin
        year = int(version.split('-')[0])
        if current_year - year > 2:
            outdated_plugins.append((name, pname, version))

    # Sort plugins by version date
    outdated_plugins.sort(key=lambda x: x[2])

    return outdated_plugins

def group_plugins(plugins):
    vim_plugins = []
    nvim_plugins = []
    unknown_plugins = []

    for plugin in plugins:
        name, pname, version = plugin
        if 'nvim' in pname.lower():
            nvim_plugins.append(plugin)
        elif 'vim' in pname.lower():
            vim_plugins.append(plugin)
        else:
            unknown_plugins.append(plugin)

    return vim_plugins, nvim_plugins, unknown_plugins

if __name__ == "__main__":
    script_dir = os.path.dirname(__file__)
    file_path = os.path.join(script_dir, 'generated.nix')
    outdated_plugins = parse_plugins(file_path)
    vim_plugins, nvim_plugins, unknown_plugins = group_plugins(outdated_plugins)

    print("\n### Neovim Plugins")
    for plugin in nvim_plugins:
        print(f"- [ ] {plugin[1]} - Version: {plugin[2]}")

    print("\n### Unknown Plugins")
    for plugin in unknown_plugins:
        print(f"- [ ] {plugin[1]} - Version: {plugin[2]}")

    print("### Vim Plugins")
    for plugin in vim_plugins:
        print(f"- [ ] {plugin[1]} - Version: {plugin[2]}")

