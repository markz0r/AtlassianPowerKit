@{
    # List of rules to disable
    Rules = @{
        PSUseSingularNouns                          = @{
            Enable = $false
        }

        PSAvoidGlobalAliases                        = @{
            Enable = $false
        }
        
        PSUseShouldProcessForStateChangingFunctions = @{
            Enable = $false
        }
        # Add other rules you want to disable here
    }
}