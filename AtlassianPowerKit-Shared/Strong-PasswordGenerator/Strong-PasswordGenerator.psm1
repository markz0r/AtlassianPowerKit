# Author: https://github.com/FranciscoNabas
function New-StrongPassword {

    [CmdletBinding()]
    param (

        # Number of characters.
        [Parameter(
            Mandatory,
            Position = 0,
            HelpMessage = 'The number of characters the password should have.'
        )]
        [ValidateRange(1, 128)]
        [int] $Length,

        # Number of non alpha-numeric chars.
        [Parameter(
            Mandatory,
            Position = 1,
            HelpMessage = 'The number of non alpha-numeric characters the password should contain.'
        )]
        [ValidateRange(1, 128)]
        [int] $NumberOfNonAlphaNumericCharacters

    )

    Begin {
        if ($Length -lt $NumberOfNonAlphaNumericCharacters) {
            throw 'The number of characters must be greater than or equal to the number of non alpha-numeric characters.'
        }
        [char[]]$global:punctuations = @('!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '_',
            '-', '+', '=', '[', '{', ']', '}', ';', ':', '>', '|',
            '.', '/', '?')
        [char[]]$global:startingChars = @('<', '&')

        function Get-IsAToZ([char]$c) {
            if ($c -lt 'a' -or $c -gt 'z') {
                if ($c -ge 'A') {
                    return $c -le 'Z'
                }
                return $false
            }
            return $true
        }

        function Get-IsDangerousString {

            param([string]$s, [ref]$matchIndex)

            $matchIndex.Value = 0
            $startIndex = 0

            while ($true) {
                $num = $s.IndexOfAny($global:startingChars, $startIndex)
                if ($num -lt 0) {
                    return $false
                }
                if ($num -eq $s.Length - 1) {
                    break
                }
                $matchIndex.Value = $num

                switch ($s[$num]) {
                    '<' {
                        if (
                            (Get-IsAToZ($s[$num + 1])) -or
                            ($s[$num + 1] -eq '!') -or
                            ($s[$num + 1] -eq '/') -or
                            ($s[$num + 1] -eq '?')
                        ) {
                            return $true
                        }
                    }
                    '&' {
                        if ($s[$num + 1] -eq '#') {
                            return $true
                        }
                    }
                }
                $startIndex = $num + 1
            }
            return $false
        }
    }

    Process {
        Add-Type -AssemblyName 'System.Security.Cryptography'

        $text = [string]::Empty
        $matchIndex = 0
        do {
            $array = New-Object -TypeName 'System.Byte[]' -ArgumentList $Length
            $array2 = New-Object -TypeName 'System.Char[]' -ArgumentList $Length
            $num = 0
            [void](New-Object -TypeName 'System.Security.Cryptography.RNGCryptoServiceProvider').GetBytes($array)

            for ($i = 0; $i -lt $Length; $i++) {
                $num2 = [int]$array[$i] % 87
                if ($num2 -lt 10) {
                    $array2[$i] = [char](48 + $num2)
                    continue
                }
                if ($num2 -lt 36) {
                    $array2[$i] = [char](65 + $num2 - 10)
                    continue
                }
                if ($num2 -lt 62) {
                    $array2[$i] = [char](97 + $num2 - 36)
                    continue
                }
                $array2[$i] = $global:punctuations[$num2 - 62]
                $num++
            }

            if ($num -lt $NumberOfNonAlphaNumericCharacters) {
                $random = New-Object -TypeName 'System.Random'

                for ($j = 0; $j -lt $NumberOfNonAlphaNumericCharacters - $num; $j++) {
                    $num3 = 0
                    do {
                        $num3 = $random.Next(0, $Length)
                    } while (![char]::IsLetterOrDigit($array2[$num3]))
                    $array2[$num3] = $global:punctuations[$random.Next(0, $global:punctuations.Length)]
                }
            }

            $text = [string]::new($array2)
        } while ((Get-IsDangerousString -s $text -matchIndex ([ref]$matchIndex)))
    }

    End {
        return $text
    }
}