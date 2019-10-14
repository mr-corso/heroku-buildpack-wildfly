#!/usr/bin/env bash

# Writes a warning message about a boolean config var having an
# invalid value other than 'true' or 'false'.
#
# Params:
#   $1:  configVar     the name of the config var
#   $2:  defaultValue  the default value of the config var
#
# Returns:
#   always 0
warning_config_var_invalid_boolean_value() {
    local configVar="$1"
    local defaultValue="$2"

    local configValue="${!configVar}"

    write_warning <<WARNING
Invalid value for ${configVar} config var: '${configValue}'
Valid values include 'true' and 'false'. Using default value '${defaultValue}'.
WARNING
}
