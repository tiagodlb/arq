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

## Build

```
zig build
```

## Testes

```
zig build test
```
