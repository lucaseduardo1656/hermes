# Buildroot — O que é, origem e funcionamento

## Origem

Surgiu em **2001** como um conjunto de scripts para facilitar a criação de sistemas Linux embarcados. O nome vem de "build root" — construir o sistema raiz (rootfs).

Antes do Buildroot, fazer um sistema Linux embarcado era assim:

```
1. Baixar código fonte do kernel manualmente
2. Baixar e compilar uma toolchain cross-compiler na mão
3. Compilar cada biblioteca manualmente na ordem certa
4. Montar o rootfs na mão
5. Descobrir que a versão da glibc é incompatível com a do kernel
6. Começar tudo de novo
```

Era um processo de dias ou semanas, cheio de incompatibilidades. O Buildroot automatizou tudo isso.

---

## O Problema que Resolve

Hardware embarcado tem arquiteturas diferentes da do PC de desenvolvimento:

```
Raspberry Pi    → CPU ARM (aarch64)
Roteador        → CPU MIPS
Câmera IP       → CPU ARM (armv7)
TV Box          → CPU ARM (cortex-a55)
Hermes (carro)  → CPU ARM (cortex-a76)
```

O PC de desenvolvimento tem CPU x86_64 — não é possível compilar um binário nele e esperar que rode num ARM. É necessário um **cross-compiler**: um compilador que roda no x86_64 mas gera código para ARM.

O Buildroot automatiza a criação da toolchain e de todo o sistema de forma reproduzível.

---

## O que o Buildroot É

```
Buildroot = sistema de build que gera sistemas Linux completos
            a partir do código fonte, para qualquer arquitetura
```

Não é uma distro. Não é um sistema operacional. É uma **fábrica de sistemas operacionais**.

A entrada é um arquivo de configuração (`.config`). A saída é uma imagem pronta para gravar no hardware.

```
┌─────────────────────────────────┐
│         hermes_defconfig        │  ← você define o que quer
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│           BUILDROOT             │
│                                 │
│  1. Compila toolchain           │
│  2. Compila kernel              │
│  3. Compila cada pacote         │
│  4. Monta o rootfs              │
│  5. Gera a imagem final         │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│      hermes-pi5.img             │  ← imagem pronta para o SD
└─────────────────────────────────┘
```

---

## As Peças que o Buildroot Compila

### 1. Toolchain (cross-compiler)
O primeiro passo — compila as ferramentas que compilarão todo o resto:

| Ferramenta | Função |
|---|---|
| binutils | assembler, linker para aarch64 |
| gcc | compilador C/C++ para aarch64 |
| glibc | biblioteca C padrão para aarch64 |
| gdb | debugger |

Tudo isso roda no PC de desenvolvimento mas gera código para o Pi.

### 2. Kernel Linux
O kernel específico para o hardware alvo. No caso do Hermes, o fork da Raspberry Pi Foundation com suporte ao BCM2712 (Pi 5).

> **Importante:** o kernel upstream do Linux não tem `bcm2712_defconfig`. Esse defconfig só existe no fork da RPi Foundation. O Buildroot oficial para Pi 5 usa um tarball de um commit específico desse fork.

### 3. Pacotes
Cada biblioteca e aplicativo habilitado no defconfig. O Buildroot tem ~3000 pacotes catalogados, cada um com seu `.mk` que descreve como baixar, compilar e instalar.

### 4. Rootfs
Monta o sistema de arquivos raiz com tudo no lugar certo: `/bin`, `/lib`, `/usr`, `/etc`, `/home`...

### 5. Imagem final
Empacota tudo num formato gravável — no caso do Hermes, um `.img` com partição FAT32 (boot) + ext4 (rootfs).

---

## Arquitetura Interna do Repositório Buildroot

```
buildroot/
├── arch/          → configurações por arquitetura (arm, x86, mips...)
├── board/         → configs de boards específicas (raspberrypi, etc)
├── boot/          → bootloaders (u-boot, grub...)
├── configs/       → defconfigs prontas (raspberrypi5_defconfig, etc)
├── fs/            → sistemas de arquivo (ext4, squashfs, fat...)
├── linux/         → regras para compilar o kernel
├── package/       → ~3000 pacotes (Qt, Mesa, busybox, python...)
│   ├── qt6base/
│   │   ├── Config.in   ← opções que aparecem no menuconfig
│   │   └── qt6base.mk  ← como baixar, compilar, instalar
│   └── ...
├── support/       → scripts auxiliares
├── toolchain/     → como construir a toolchain
└── Makefile       → ponto de entrada de tudo
```

---

## Ciclo de Vida de um Pacote

Cada pacote segue um ciclo com stamps (arquivos de controle que evitam retrabalho):

```
.stamp_downloaded    → código fonte baixado
.stamp_extracted     → descompactado
.stamp_patched       → patches aplicados
.stamp_configured    → ./configure executado
.stamp_built         → make executado
.stamp_installed     → make install executado
```

Se a build falha em `.stamp_configured`, na próxima vez o Buildroot pula download e extração e tenta direto do configure. É por isso que `make` após um erro retoma de onde parou.

Para forçar a recompilação de um pacote específico:
```bash
make <pacote>-dirclean   # apaga tudo do pacote
make <pacote>            # recompila do zero
```

---

## BR2_EXTERNAL

O Buildroot foi projetado para ser usado "de fora" sem modificar seu código. O conceito de **BR2_EXTERNAL** permite manter as customizações num repositório separado:

```
buildroot/        → repositório oficial intocado (submodule)
hermes/           → nosso BR2_EXTERNAL
  ├── configs/hermes_pi5_defconfig   → nossa config
  ├── board/hermes-pi5/              → nossos arquivos de board
  ├── package/                       → nossos pacotes customizados
  ├── Config.in                      → integração com menuconfig
  ├── external.desc                  → identifica o external tree
  └── external.mk                    → integração com o build system
```

Ao rodar `make BR2_EXTERNAL=..`, o Buildroot mescla o nosso tree com o dele. Nossos pacotes aparecem no `menuconfig` junto com os oficiais.

---

## Gerenciador de Pacotes

**Não existe** no sistema final. O Buildroot produz um sistema fechado — o que foi compilado é o que existe. Não há `apt`, `pacman`, `pip` nem nada similar no target.

Para adicionar um pacote ao sistema:
1. Habilitar no defconfig (`BR2_PACKAGE_NOME=y`)
2. Rodar `make`
3. Regravar o SD card

Para desenvolvimento, é possível copiar binários diretamente via `scp` sem precisar regravar o SD.

---

## Comparativo com Outras Abordagens

| | Buildroot | Yocto | Debian/Ubuntu | Alpine |
|---|---|---|---|---|
| Complexidade | Média | Alta | Baixa | Baixa |
| Tamanho da imagem | ~50-500MB | ~100MB-1GB | ~1-4GB | ~100-300MB |
| Boot time | ~5-10s | ~8-15s | ~20-40s | ~15-25s |
| Gerenc. pacotes | Não | Não | apt | apk |
| Reproducibilidade | Total | Total | Parcial | Parcial |
| Curva de aprendizado | Semanas | Meses | Dias | Dias |
| Usado por | Embarcado, IoT | Indústria automotiva | Servidores, desktop | Containers, edge |

**Yocto** é o padrão da indústria automotiva (Android Automotive, AGL). É mais poderoso que o Buildroot mas muito mais complexo — projetos industriais têm times dedicados só para Yocto. Para um projeto pessoal, Buildroot é a escolha certa.

---

## O que Acontece ao Rodar `make`

```
1. Lê o .config
2. Resolve dependências entre pacotes
3. Compila a toolchain (gcc, binutils, glibc para aarch64)
4. Para cada pacote habilitado, em ordem de dependência:
   a. Baixa o tarball (ou clona o git)
   b. Verifica o hash SHA256
   c. Descompacta
   d. Aplica patches (inclusive os de board/hermes-pi5/patches/)
   e. Configura (cmake / autoconf) com a toolchain cross
   f. Compila
   g. Instala no staging/ (sysroot temporário) e no target/
5. Copia o rootfs-overlay por cima do target/
6. Executa post-build.sh
7. Gera a imagem com genimage
8. Executa post-image.sh
```

A primeira build leva horas porque compila tudo do zero. Rebuilds são rápidos porque os stamps evitam retrabalho.

---

## Quem Usa Buildroot

- **OpenWrt** — sistema para roteadores, derivado do Buildroot
- **Sistemas industriais** — CLPs, painéis HMI, equipamentos médicos
- **Câmeras IP, drones** — sistemas embarcados em geral
- **Pesquisa** — sistemas mínimos para experimentos acadêmicos
- **Hermes** — sistema de multimídia automotivo deste projeto
