# TODO Make this into a runspace/thread so it doesn't need to consume an entire powershell window
# TODO ALT Could also just add the ShowWindow function and set the window to hidden
    # This would mean you have to kill it in taskmgr though
        # Maybe another hot-key to end it?

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class fade{
    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern int SetLayeredWindowAttributes(IntPtr hwnd, uint crKey, byte bAlpha, uint dwFlags);

    [DllImport("user32.dll")]
    public static extern int GetLayeredWindowAttributes(IntPtr hWnd, ref uint crKey, ref byte bAlpha, ref uint dwFlags);    

    [DllImport("user32.dll")]
    public static extern int SetWindowLongPtrA(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll")]
    public static extern int GetWindowLongPtrA(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll")]
    public static extern int GetAsyncKeyState(int vKey);

    [DllImport("user32.dll")]
    public static extern int GetKeyState(int vKey);
}
"@

$modified = $false
$fade = 128 # Ranges from 0 (invisible) to 255 (normal, opaque)
$fadeStep = 16
$settings = @{}
while($true){
    [System.Threading.Thread]::Sleep(15)
    if([fade]::GetKeyState(0x13) -gt 1){
        $fg = [fade]::GetForegroundWindow()
        # Find window with focus

        $prevSettings = 0
        if($settings.ContainsKey($fg)){ # If previously seen window
            $prevSettings = $settings.$fg
            # Recall saved settings
        }else{
            $prevSettings = [fade]::GetWindowLongPtrA($fg,-20)
            # Get the extended window settings
            $settings.$fg = $prevSettings
            # Store them in the hashtable
        }

        if($prevSettings -band -bnot 0x80000){
            [void][fade]::SetWindowLongPtrA($fg, -20, ($prevSettings -bor 0x80000))
        }
        # Pause/break pressed so at a minimum we need to force the layered style to check alpha

        $colorKey = 0
        $alpha = 255
        $flags = 2
        $retVal = [fade]::GetLayeredWindowAttributes($fg, [ref]$colorKey, [ref]$alpha, [ref]$flags)
        # This is a pass by ref function so the variables need to exist first and their value gets updated

        if($retVal){ # If call succeeded
            if($alpha -eq 0){$alpha = 255} # The first succesful call has alpha 0. IDK

            # Store value of current fade settings
            $newAlpha = $fade

            if($alpha -lt 255 -and !$modified){$newAlpha = 255}
            # Decide if we are making opaque or not, ignore wrap around from modify

            [void][fade]::SetLayeredWindowAttributes($fg, 0, $newAlpha, 2)
            # Set the new value

            if([fade]::GetKeyState(0x10) -gt 1){ # If holding shift
                while([fade]::GetKeyState(0x13) -gt 1){[void]''}
                # Wait until they let go of both shift and pause/break
            }else{
                while([fade]::GetKeyState(0x13) -gt 1){
                    $modified = $false
                    if([fade]::GetKeyState(0x26) -gt 1 -and $newAlpha -ne 255){ # Up arrow
                        $fade+=$fadeStep; if($fade -gt 254){$fade = 254}
                        while([fade]::GetKeyState(0x26) -gt 1){[void]''}
                        #[System.Threading.Thread]::Sleep(50)
                        $modified = $true
                        break
                    }elseif([fade]::GetKeyState(0x28) -gt 1 -and $newAlpha -ne 255){ # Down arrow
                        $fade-=$fadeStep; if($fade -lt 1){$fade = 1}
                        while([fade]::GetKeyState(0x28) -gt 1){[void]''}
                        #[System.Threading.Thread]::Sleep(50)
                        $modified = $true
                        break
                    }
                }
                # Wait until they let go of pause/break

                if($modified){
                    $alpha = 255
                    # If we are modified, then the only possible restore value is 255
                    continue
                }
                [void][fade]::SetLayeredWindowAttributes($fg, 0, $alpha, 2)
                # Return the state to what it was
            }

            $retVal = [fade]::GetLayeredWindowAttributes($fg, [ref]$colorKey, [ref]$alpha, [ref]$flags)
            # Last check on current alpha value
            if($retVal -and $alpha -eq 255){ # If alpha = 255, then we must be done with it, change the style back
                [void][fade]::SetWindowLongPtrA($fg, -20, $prevSettings)
            }
        }
    }
}
