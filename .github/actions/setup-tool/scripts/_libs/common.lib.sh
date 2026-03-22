##
# @description Normalize version to vX.Y.Z format
# @arg $1 string Raw version string
# @stdout Normalized version (X.Y.Z)
# @return 0 on success, 1 on invalid format
normalize_version() {
  local version="$1"

  # Remove v/V prefix
  version="${version#v}"
  version="${version#V}"

  # Extract version number (first 3 digit groups)
  # major/minor: 1-3 digits, patch: 1+ digits
  # Suffixes like -beta are not allowed
  if [[ ! "$version" =~ ^([0-9]{1,3})(\.[0-9]{1,3})?(\.[0-9]+)?$ ]]; then
    echo "Error: Invalid version format: $version" >&2
    return 1
  fi

  local major="${BASH_REMATCH[1]}"
  local minor="${BASH_REMATCH[2]#.}"
  local patch="${BASH_REMATCH[3]#.}"

  # Set default values
  minor="${minor:-0}"
  patch="${patch:-0}"

  # Return in vX.Y.Z format
  echo "${major}.${minor}.${patch}"
}
