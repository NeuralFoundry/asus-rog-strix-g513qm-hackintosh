/*
 * ASUS ROG Strix G513QM: the SK Hynix BC711 NVMe (HFM001TD3JX013N, Windows drive) kernel-panics macOS's
 * IONVMeFamily. Hide \_SB.PCI0.GPP6.NVME (PCI 0:2.4 -> 0.0) under Darwin only; Windows is unaffected.
 */
DefinitionBlock ("", "SSDT", 2, "G513QM", "NVMeOff", 0x00000000)
{
    External (_SB_.PCI0.GPP6.NVME, DeviceObj)

    Scope (\_SB.PCI0.GPP6.NVME)
    {
        Method (_STA, 0, NotSerialized)  // _STA: Status
        {
            If (_OSI ("Darwin"))
            {
                Return (Zero)
            }
            Else
            {
                Return (0x0F)
            }
        }
    }
}
