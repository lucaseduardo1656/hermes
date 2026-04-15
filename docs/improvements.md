# Melhorias Pendentes — Hermes Pi5

## 1. DRM_VC4 como built-in (prioridade média)

**Estado atual:** `CONFIG_DRM_VC4=m` — carregado como módulo via modprobe no boot.

**Problema:** `SND=m` e `SND_SOC=m` impedem `DRM_VC4=y` (Kconfig: driver built-in não pode
depender de módulo). O cage/hermes só inicia após o modprobe do vc4, o que adiciona ~2-3s
ao boot e introduz uma condição de corrida coberta pelo `Restart=on-failure`.

**Fix:** Adicionar ao `linux-gpu.fragment`:
```
CONFIG_SND=y
CONFIG_SND_SOC=y
CONFIG_DRM_VC4=y
```
Requer rebuild completo do kernel.

---

## 2. Qt fontconfig não inicializa (prioridade baixa)

**Estado atual:** `QT_QPA_FONTDIR=/usr/share/fonts/liberation` no hermes.service.

**Problema:** Qt6 foi compilado com `FEATURE_fontconfig=ON` e `libfontconfig.so.1` está
linkado, mas `FcInit()` falha silenciosamente em runtime — Qt cai no `QBasicFontDatabase`
e procura `/lib/fonts`. A causa exata não foi determinada (possível conflito de ambiente
entre o processo cage e fontconfig).

**Fix proposto:** Investigar com `FC_DEBUG=1` e verificar se o problema é versão do
cache ou permissões no `/var/cache/fontconfig/`. Se confirmado que fontconfig nunca vai
funcionar nesse contexto, a solução atual com `QT_QPA_FONTDIR` é definitiva.

---

## 3. Locale UTF-8 (prioridade baixa)

**Estado atual:** Warning no boot: `Detected locale "C" with character encoding "ANSI_X3.4-1968"`.

**Problema:** O sistema não tem dados de locale gerados. `LANG=C.UTF-8` está no service
mas não é reconhecido como UTF-8.

**Fix:** Adicionar ao defconfig:
```
BR2_TOOLCHAIN_BUILDROOT_LOCALE=y
BR2_GENERATE_LOCALE="C.UTF-8 pt_BR.UTF-8"
```
Ou usar `LANG=en_US.UTF-8` com o locale gerado. Não afeta funcionamento do sistema.

---

## 4. Dependência de boot do vc4 (prioridade baixa)

**Estado atual:** `Restart=on-failure` no hermes.service cobre a condição de corrida.

**Fix mais limpo:** Adicionar ao `[Unit]` do hermes.service:
```
After=sys-subsystem-module-vc4.device
```
Ou criar `/etc/modules-load.d/vc4.conf` com `vc4` para garantir carregamento antes
do systemd multi-user.target.
