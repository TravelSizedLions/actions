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
addons_path="./addons/$repo/addons.jsonc"
plugin_path="./addons/$repo/plugin"
cfg_path="$plugin_path.cfg"
toml_path="$plugin_path.toml"

missing_dasel=$(which dasel | grep "dasel not found")
if [[ -n $missing_dasel ]]; then
  echo "Missing dependency 'dasel'. Install with 'sudo apt-get install dasel'"
  usage $usage
  exit 1
fi

if [[ ! -e "$addons_path" && ! -e "$cfg_path" ]]; then
  echo "This repository has no versioning system!"
  exit 1;
fi

next_version=''
if [[ -e "$addons_path" ]]; then
  addons=$(cat $addons_path)
  addons_version=$(echo $addons | jq ".version" | tr -d '"')
  next_version=$(echo $addons_version | awk -F. '{$NF = $NF + 1;} 1' OFS=.)
  addons=$(echo $addons | jq --arg v $next_version '.version = $v')
  echo $addons | jq . > $addons_path
  echo "Bumped addons.json version: ${addons_version} -> ${next_version}"
fi

if [[ -e "$cfg_path" ]]; then
  mv "$cfg_path" "$toml_path"
  plugin_version=$(dasel select -f "$toml_path" -r toml -s "plugin.version" | tr -d "'")
  
  if [[ -z $next_version ]]; then
    next_version=$(echo "$plugin_version" | awk -F. '{$NF = $NF + 1;} 1' OFS=.)    
  fi

  dasel put -t string -v "$next_version" -f "$toml_path" -r toml "plugin.version" 
  mv "$toml_path" "$cfg_path"
  echo "Bumped plugin.cfg version: ${plugin_version} -> ${next_version}"
fi

if [[ -n $GITHUB_OUTPUT ]]; then
  echo "Exporting version info: ${next_version}"
  echo "next_version=${next_version}" >> $GITHUB_OUTPUT
fi
