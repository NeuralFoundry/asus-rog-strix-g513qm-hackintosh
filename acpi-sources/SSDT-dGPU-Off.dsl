/*
 * ASUS ROG Strix G513QM (Ryzen 7 5800H + RTX 3060): power the NVIDIA dGPU off under macOS.
 * In this DSDT/SSDT (Nv18dGPU) the dGPU is \_SB.PCI0.GPP0.PEGP and its power resource is
 * \_SB.PCI0.GPP0.M237 (_ON/_OFF, referenced by _PR3). PEGP has no _OFF of its own, so M237._OFF is called,
 * falling back to GPP0._PS3. Darwin only.
 */
DefinitionBlock ("", "SSDT", 2, "G513QM", "dGPUOff", 0x00000000)
{
    External (_SB_.PCI0.GPP0, DeviceObj)
    External (_SB_.PCI0.GPP0.PEGP, DeviceObj)
    External (_SB_.PCI0.GPP0.M237._OFF, MethodObj)    // 0 Arguments
    External (_SB_.PCI0.GPP0._PS3, MethodObj)         // 0 Arguments

    Device (RMD1)
    {
        Name (_HID, "RMD10000")  // _HID: Hardware ID
        Method (_STA, 0, NotSerialized)  // _STA: Status
        {
            If (_OSI ("Darwin"))
            {
                Return (0x0F)
            }
            Else
            {
                Return (Zero)
            }
        }

        Method (_INI, 0, NotSerialized)  // _INI: Initialize
        {
            If (_OSI ("Darwin"))
            {
                If (CondRefOf (\_SB.PCI0.GPP0.M237._OFF))
                {
                    \_SB.PCI0.GPP0.M237._OFF ()
                }
                ElseIf (CondRefOf (\_SB.PCI0.GPP0._PS3))
                {
                    \_SB.PCI0.GPP0._PS3 ()
                }
            }
        }
    }
}
