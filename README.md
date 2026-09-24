# CHIP-8

Emulador de CHIP-8 escrito em Zig.

Este projeto e baseado nos exercicios do livro System Programming with Zig
(atualmente em MEAP), que usa a implementacao de um interpretador CHIP-8
como estudo de caso para programacao de sistemas em Zig.

## Estrutura

- `src/vm.zig` - implementacao da maquina virtual (CPU, memoria, registradores)
- `src/app.zig` - ponto de entrada da aplicacao
- `src/root.zig` - modulo raiz da lib
- `src/tests.zig` - testes
- `src/font.bin` - fonte padrao do CHIP-8

## Arquitetura

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ARQUITETURA DO CHIP-8 (ZIG)                         │
└─────────────────────────────────────────────────────────────────────────────┘

                  ┌────────────────────────────────────────┐
                  │              PERIFÉRICOS               │
                  │  ┌──────────────────┐ ┌─────────────┐  │
                  │  │ Display          │ │ Keypad      │  │
                  │  │ pixels: [32][64] │ │ keys: [16]  │  │
                  │  └────────▲─────────┘ └──────▲──────┘  │
                  └───────────┼──────────────────┼─────────┘
                              │ (Desenho)        │ (Teclas)
                              │                  │
┌─────────────────────────────┼──────────────────┼────────────────────────────┐
│ Memory Struct (CPU + Registradores)            │                            │
│                                                │                            │
│  ┌───────────────────────┐  ┌──────────────┐  ┌┴─────────────┐              │
│  │ pc : u12              │  │ i : u12      │  │ vars : [16]u8│              │
│  │ (Program Counter)     │  │ (Index Reg)  │  │ (V0 até VF)  │              │
│  └──────────┬────────────┘  └──────▲───────┘  └──────▲───────┘              │
│             │                      │                 │                      │
│             │ Aponta endereço      │ Escreve/Lê      │ Lê/Modifica          │
│             ▼                      │                 │                      │
│  ┌─────────────────────────────────┴─────────────────┴───────────────────┐  │
│  │ CICLO DE EXECUÇÃO: step() ──► readBytes() ──► readBytecode()          │  │
│  │                                                                       │  │
│  │  1. Busca 2 bytes em data[pc]                                         │  │
│  │  2. Quebra em 4 nibbles                                               │  │
│  │  3. Executa o Opcode:                                                 │  │
│  │     - 0x1, 0xB ───────► Modifica pc (Desvios/Pulos)                   │  │
│  │     - 0xA, 0xF ───────► Modifica i (Ponteiro de Memória)              │  │
│  │     - 0x6, 0x7, 0x8 ──► Modifica vars[X] (Registradores V)            │  │
│  └─────────────────────────────────┬─────────────────────────────────────┘  │
│                                    │                                        │
└────────────────────────────────────┼────────────────────────────────────────┘
                                     │ Leitura/Escrita de Dados/Instruções
                                     ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ MEMÓRIA RAM (data: [0x1000]u8 — 4096 bytes)                                 │
│                                                                             │
│ 0x000 ┌─────────────────────────────────────────────────────────┐           │
│       │ Reservado para o Sistema (Sprites de fontes, etc.)      │           │
│ 0x1FF ├─────────────────────────────────────────────────────────┤           │
│ 0x200 │ Espaço da ROM (program_load_addr)                       │           │
│       │ (Onde o pc começa a ler as instruções)                  │           │
│ 0xFFF └─────────────────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Build

```
zig build
```

## Testes

```
zig build test
```
