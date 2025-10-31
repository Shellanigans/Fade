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
$fadeMin = 16
$fadeMax = 238

$settings = @{}
while($true){
    [System.Threading.Thread]::Sleep(15)
    try{
        if([fade]::GetKeyState(0x13) -gt 1){
            $fg = [fade]::GetForegroundWindow()
            # Find window with focus

            if($settings.ContainsKey($fg)){ # If previously seen window
                $prevSettings = $settings.$fg.windowSettings
                # Recall saved settings
            }else{
                $prevSettings = [fade]::GetWindowLongPtrA($fg,-20)
                # Get the extended window settings
                $settings.$fg = @{
                    isFaded = $false
                    currAlpha = 128
                    windowSettings = $prevSettings
                }
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

                $settings.$fg.isFaded = !$settings.$fg.isFaded
                if($settings.$fg.isFaded){
                    [void][fade]::SetLayeredWindowAttributes($fg, 0, $settings.$fg.currAlpha, 2)
                }else{
                    [void][fade]::SetLayeredWindowAttributes($fg, 0, 255, 2)
                }

                if([fade]::GetKeyState(0x10) -gt 1){ # If holding shift
                    while([fade]::GetKeyState(0x13) -gt 1){[void]$null}
                    # Wait until they let go of both shift and pause/break
                    $settings.$fg.isFaded = !$settings.$fg.isFaded
                }else{
                    while([fade]::GetKeyState(0x13) -gt 1){
                        if([fade]::GetKeyState(0x26) -gt 1 -and $settings.$fg.isFaded){ # Up arrow
                            $settings.$fg.currAlpha+=$fadeStep
                            if($settings.$fg.currAlpha -gt 239){$settings.$fg.currAlpha = 239}
                            while([fade]::GetKeyState(0x26) -gt 1){[void]$null}
                            # Wait until they let go of up arrow key
                            if($settings.$fg.isFaded){[void][fade]::SetLayeredWindowAttributes($fg, 0, $settings.$fg.currAlpha, 2)}
                        }elseif([fade]::GetKeyState(0x28) -gt 1 -and $settings.$fg.isFaded){ # Down arrow
                            $settings.$fg.currAlpha-=$fadeStep
                            if($settings.$fg.currAlpha -lt 16){$settings.$fg.currAlpha = 16}
                            while([fade]::GetKeyState(0x28) -gt 1){[void]$null}
                            # Wait until they let go of down arrow key
                            if($settings.$fg.isFaded){[void][fade]::SetLayeredWindowAttributes($fg, 0, $settings.$fg.currAlpha, 2)}
                        }
                    }
                }

                $settings.$fg.isFaded = !$settings.$fg.isFaded
                if($settings.$fg.isFaded){
                    [void][fade]::SetLayeredWindowAttributes($fg, 0, $settings.$fg.currAlpha, 2)
                }else{
                    [void][fade]::SetLayeredWindowAttributes($fg, 0, 255, 2)
                }
            }
        }
        # Wait until they let go of pause/break
    }catch{}
}
