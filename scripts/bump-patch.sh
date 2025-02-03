#!/bin/bash
usage="
USAGE: ./version-bump.sh <repo name>
"

if [[ -z $1 ]]; then
  echo "Missing repository name"
  echo $usage
  exit 1;
fi

repo=$1
addons_root_path="./addons.jsonc"
addons_path="./addons/$repo/addons.jsonc"
plugin_path="./addons/$repo/plugin"
cfg_path="$plugin_path.cfg"
toml_path="$plugin_path.toml"

missing_dasel=$(which dasel | grep "dasel not found")
if [[ -n $missing_dasel && ! -e "$cfg_path" ]]; then
  echo "Missing dependency 'dasel'. Install with 'sudo apt-get install dasel'"
  usage $usage
  exit 1
fi

if [[ ! -e "$addons_root_path" && ! -e "$addons_path" && ! -e "$cfg_path" ]]; then
  echo "This repository has no versioning system!"
  exit 1;
fi

next_version=''
if [[ -e "$addons_path" || -e "$addons_root_path" ]]; then
  # Fall back to root repo addons.json if we're not dealing with an addon repository.
  actual_path="$addons_root_path"
  if [[ -e "$addons_path" ]]; then
    actual_path="$addons_path"
  fi

  # Load the file
  addons=$(cat $actual_path)

  # Extract and bump the patch version
  addons_version=$(echo $addons | jq ".version" | tr -d '"')
  next_version=$(echo $addons_version | awk -F. '{$NF = $NF + 1;} 1' OFS=.)
  
  # Rebuild the file's contents with the correct version string
  addons=$(echo $addons | jq --arg v $next_version '.version = $v')
 
  # Write & report.
  echo $addons | jq . > $actual_path
  echo "Bumped addons.json version: ${addons_version} -> ${next_version}"
fi

if [[ -e "$cfg_path" ]]; then
  # For some reason dasel doesn't like the *.cfg extension, so we rename temporarily
  mv "$cfg_path" "$toml_path"

  # Get the current version
  plugin_version=$(dasel select -f "$toml_path" -r toml -s "plugin.version" | tr -d "'")
  
  # Use the bumped addons version if it's already been calculated.
  if [[ -z $next_version ]]; then
    next_version=$(echo "$plugin_version" | awk -F. '{$NF = $NF + 1;} 1' OFS=.)    
  fi

  # Write the new version
  dasel put -t string -v "$next_version" -f "$toml_path" -r toml "plugin.version" 
  mv "$toml_path" "$cfg_path"

  # Report.
  echo "Bumped plugin.cfg version: ${plugin_version} -> ${next_version}"
fi

# Export the new version string for use in the consuming github action (if appropriate).
if [[ -n $GITHUB_OUTPUT ]]; then
  echo "Exporting version info: ${next_version}"
  echo "next_version=${next_version}" >> $GITHUB_OUTPUT
fi
