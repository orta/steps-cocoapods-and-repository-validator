#!/bin/bash

THIS_SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${THIS_SCRIPTDIR}/_bash_utils/utils.sh"
source "${THIS_SCRIPTDIR}/_bash_utils/formatted_output.sh"


# find project or workspace directories
branch="$1"
projects=()

write_section_to_formatted_output "### Searching for Xcode project files, on branch: ${branch}"


IFS=$'\n'
for path in $(find . -type d -name '*.xcodeproj' -or -name '*.xcworkspace')
do
  already_stored=false
  for project in "${projects[@]}"
  do
    if [[ "${path}" == "${project}"* ]]; then
      already_stored=true
      echo_string_to_formatted_output "* **[skip]** project file found as *sub directory in another project / workspace directory* - **skipping**: $path"
    fi
  done

  if ! ${already_stored}; then
    echo_string_to_formatted_output "* project file **found** at: ${path}"
    projects+=("$path")
  fi
done
unset IFS

write_section_to_formatted_output "### Scanning configurations in found project files"

# Get the project schemes
projects_encoded=()
for project in "${projects[@]}"
do
  echo "-> Inspecting project: ${project}"

  xcodebuild_output=()
  schemes=()
  schemes_encoded=()
  parse_schemes=false

  IFS=$'\n'
  if [[ "${project}" == *".xcodeproj" ]]; then
    xcodebuild_output=($(gtimeout 20 xcodebuild -list -project "${project}"))
  else
    xcodebuild_output=($(gtimeout 20 xcodebuild -list -workspace "${project}"))
  fi
  unset IFS

  echo " (i) xcodebuild_output: ${xcodebuild_output}"

  for line in "${xcodebuild_output[@]}"
  do
    echo " (i) line: ${line}"
    # trimming
    #  source: http://stackoverflow.com/a/3232433/974381
    trimmed_line=$([[ "$line" =~ [[:space:]]*([^[:space:]]|[^[:space:]].*[^[:space:]])[[:space:]]* ]]; echo -n "${BASH_REMATCH[1]}")
    echo "  (i) trimmed_line: ${trimmed_line}"
    if ${parse_schemes}; then
      schemes+=(${trimmed_line})
      schemes_encoded+=($(printf "%s" "${trimmed_line}" | base64))
      echo "   (i) schemes_encoded: ${schemes_encoded}"
    fi

    if [[ ${trimmed_line} == *"Schemes:"* ]]; then
      parse_schemes=true
    fi
  done

  if [[ ${#schemes[@]} == 0 ]]; then
    write_section_to_formatted_output "**${project}**"
    echo_string_to_formatted_output "**ignoring**: no (*shared*) schemes found."
  else
    IFS=" "
    scheme_list="${schemes[*]}"
    unset IFS
    write_section_to_formatted_output "**${project}**"
    write_section_to_formatted_output "detected schemes:"
    echo_string_to_formatted_output "    ${scheme_list}"

    IFS=","
    encoded_scheme_list="${schemes_encoded[*]}"
    unset IFS
    echo "-> Store found project configurations information to file..."
    echo "$(printf "%s" "$branch" | base64),$(printf "%s" "$project" | base64),$encoded_scheme_list" >> ~/.schemes
    echo "-> Found project configurations information stored for project: ${project}"
    # echo " [i] Final schemes info:"
    # cat ~/.schemes
    # echo " ---"
  fi
done
