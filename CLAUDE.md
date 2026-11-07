# CLAUDE.md

HMUF02-V05 (Qualcomm MSM8916) 4G USB dongle'ı Debian çalıştıran başsız mini PC'ye çevirme projesi. Dil: Türkçe.

- Cihazla ilgili her işte önce `.claude/skills/msm8916-dongle/SKILL.md` kurallarını uygula (yedek olmadan yazma yok, cihaza özel bölümler, tz+hyp birlikte).
- Platform: Windows 10 + PowerShell 5.1. Derleme işleri Linux/WSL2 veya GitHub Actions'ta yapılır.
- `backups/`, `tools/`, `third_party/`, `.venv/`, `build/` git dışıdır. Araçları yeniden almak için `scripts/windows/setup-tools.ps1`.
- Durum ve yol haritası: `README.md`. Ayrıntılar: `docs/`.
