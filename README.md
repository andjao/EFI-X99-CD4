# EFI-X99-CD4

EFI (Extensible Firmware Interface) configurada para **Huananzhi X99 CD4** com suporte completo a **macOS**.

## 🖥️ Especificações do Hardware

| 💻 **Componente**        | 🔧 **Detalhes**                         |
| ------------------------ | --------------------------------------- |
| 🖥️ **Placa-mãe**        | Huananzhi X99 CD4                       |
| ⚙️ **Processador**       | Intel Xeon E5-2667 v4 @ 3.20 GHz        |
| 💾 **Memória**           | 4× Kllisre 8 GB 2400 MHz (32 GB Total)  |
| 🎮 **GPU**               | Radeon RX 6750 XT (12 GB)               |
| 🔊 **Áudio**             | Realtek ALC897                          |
| 🌐 **Rede Cabeada**      | Realtek PCIe GbE Family Controller      |
| 🛜 **Wi-Fi / Bluetooth** | Fenvi PCIe BCM94360CD (4 Antenas)       |
| 🪟 **NVMe (Windows)**     | Netac NVMe SSD 512 GB (PCI-E 4.0 ×4)    |
| 🍎 **NVMe (macOS)**      | Netac NVMe SSD 250 GB (PCI-E 4.0 ×4)    |
| 🎮 **NVMe (Jogos)**      | Kingston SNV3S1000G 1 TB (PCI-E 4.0 ×4) |
| 🔧 **SSD (Outros)**      | Goldenfir 512 GB (SATA 3.0)             |

## 📈 Performance (Geekbench v6)

- **Single Core**: 1195
- **Multi Core**: 6451

## 📁 Estrutura

```
EFI/
├── BOOT/
│   └── BOOTx64.efi
└── OC/
    ├── config.plist
    ├── OpenCore.efi
    ├── ACPI/              # SSDT patches customizadas
    ├── Drivers/           # EFI drivers necessários
    ├── Kexts/             # Kernel extensions
    ├── Resources/         # Fontes, imagens, áudio
    └── Tools/             # Ferramentas utilitárias

USBMaps/
├── HUB Internal USB/
└── Single Internal USB/
```

## 🔧 Componentes Principais

### ACPI
- `DMAR.aml` — Drop table DMAR
- `SSDT-EC.aml` — Embedded Controller
- `SSDT-GPRW.aml` — Wake method patch
- `SSDT-HPET.aml` — HPET timer patch
- `SSDT-PLUG.aml` — Power management
- `SSDT-RTCAWAC.aml` — RTC/AWAC patch
- `SSDT-SBUS-MCHC.aml` — SMBus/Memory Controller
- `SSDT-UNC.aml` — Uncore controller
- `SSDT-USBX.aml` — USB power properties

### Drivers EFI
- `AudioDxe.efi` — Suporte a áudio na EFI
- `FirmwareSettingsEntry.efi` — Entrada Firmware Settings
- `HfsPlus.efi` — Suporte HFS+
- `OpenCanopy.efi` — UI do OpenCore
- `OpenRuntime.efi` — Runtime do OpenCore
- `ResetNvramEntry.efi` — Entrada Reset NVRAM

### Kexts Instalados
- **Lilu.kext** (v1.7.1) — Plugin framework
- **VirtualSMC.kext** (v1.3.7) — SMC emulation
- **SMCProcessor.kext** (v1.3.7) — CPU sensor
- **SMCSuperIO.kext** (v1.3.7) — System monitoring
- **AppleALC.kext** (v1.9.6) — Audio (ALC897)
- **RealtekRTL8111.kext** (v2.4.2) — Ethernet
- **NootRX.kext** (v1.0.0) — GPU patch (AMD)
- **NVMeFix.kext** (v1.1.3) — NVMe fixes
- **CpuTscSync.kext** (v1.1.2) — CPU TSC sync
- **FeatureUnlock.kext** (v1.1.8) — Features unlock
- **RestrictEvents.kext** (v1.1.6) — Event patching
- **XHCI-unsupported.kext** (v0.9.2) — XHCI controller
- **AMFIPass.kext** (v1.4.1) — AMFI bypass
- **IO80211FamilyLegacy.kext** (v1200.12.2b1) — WiFi legacy support
- **IOSkywalkFamily.kext** (v1.0) — IOSkywalk framework (Sonoma+)

### USB Maps
Inclui mappings customizados para:
- HUB USB interno
- Porta USB única interna

## 🚀 Como Usar

### 1. Preparar o Pen Drive / SSD

1. Formate seu dispositivo como **GUID/GPT** e **APFS**
2. Copie a pasta `EFI` para a partição EFI do dispositivo:
   ```bash
   cp -r EFI /Volumes/EFI/
   ```
3. Configurações da BIOS:
   1. Advanced - ACPI Settings - ACPI Sleep State - Suspended Disabled
   2. Advanced - NCT5532D Super IO Configuration - Serial Port 1 Configuration - Serial Port - Disabled
   3. Advanced - CSM Configuration - Video - UEFI
   4. Advanced - USB Configuration - XHCI Hand-off - Enabled
   5. Advanced - USB Configuration - EHCI Hand-off - Enabled
   6. IntelRCSetup - Processdor Configuration - MSR Lock Control - Disabled
   7. Reboot + BIOS novamente
   8. Advanced - CSM Configuration - CSM Support - Disabled

## ⚙️ Configuração do OpenCore

### Bootloader
- **LauncherPath**: Default
- **ShowPicker**: true
- **Timeout**: 5s
- **HideAuxiliary**: true

### Kernel
- **Scheme**: x86_64
- **Emulate**: CPUID patched para Ivy Bridge
- **Quirks**: Customizados para Xeon E5 v4

### NVRAM
- **CSR Configuration**: Disabled (SIP desativado)
- **Boot Arguments**: `keepsyms=1 debug=0x100 npci=0x2000 alcid=13`

### Platform Info
- **Model**: MacPro7,1
- **ProcessorType**: Xeon (3841)

## 📝 Notas Importantes

### Antes de Usar

1. **Edite `config.plist`**:
   - Gere um **SMBIOS válido** (MLB, ROM, Serial, UUID)
   - Use [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) para isso

2. **Verifique as versões dos kexts**:
   - Compare com a [última versão no GitHub](https://github.com/acidanthera)

3. **Customize o áudio**:
   - `alcid=13` é configurado por padrão para ALC897
   - Ajuste em `config.plist` → NVRAM → 7C436110... → boot-args se necessário

### Compatibilidade macOS

Testada em:
- macOS 26.1 (Tahoe)

### Requisitos Mínimos

- **BIOS**: Atualizado
- **Disco**: Formatado como APFS
- **Partição EFI**: Mínimo 200MB
- **USB/Pen Drive**: Para installer do macOS (se necessário)

## 🐛 Troubleshooting

### Boot não inicializa
- Verifique se a pasta EFI está na partição EFI correta
- Confirme se o BIOS está booting de UEFI

### Problemas com áudio
- Ajuste `alcid` em config.plist (testar valores: 11, 12, 13, 21, 22, 23, 66, 69, 77, 98, 99)
- Verifique se `AppleALC.kext` está ativo e `MyKextInstaller` está instalado

### Rede não funciona
- Confirme driver `RealtekRTL8111.kext` está ativo.
- Verifique Device Properties em config.plist

### GPU não detectada
- Verifique `NootRX.kext` para AMD
- Confirme Power Management em BIOS está ativo

## 📚 Recursos Úteis

- [OpenCore Official Guide](https://dortania.github.io/OpenCore-Install-Guide/)
- [Acidanthera GitHub](https://github.com/acidanthera)
- [OLARILA Community](https://www.olarila.com/)
- [Luchina - Comunidade Brasileira](https://luchina.com.br/)

## 📄 Licença

Esta EFI é fornecida como está para fins educacionais e compatibilidade de hardware específico.

## 🙏 Créditos

- OpenCore bootloader por [Acidanthera](https://github.com/acidanthera)
- Configuração base por **Luchina** (https://luchina.com.br)
- Melhorias e otimizações para X99 CD4

---

**Versão**: `1.0.6` (OpenCore REL-106-2025-11-03)

**Última atualização**: 11 de Novembro de 2025
