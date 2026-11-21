#!/usr/bin/env bash
set -euo pipefail

memoria="$(dirname "$0")/../memoria"
cd "$memoria"

pandoc --defaults=../herramientas/memoria_pdf.yaml \
  --include-in-header=../herramientas/memoria_pdf.tex \
  01_descripcion_problema.md 02_glosario.md 03_requisitos.md \
  04_modelo_conceptual.md 05_modelo_relacional.md 06_modelo_tecnologico.md \
  anexo_a_cambios.md anexo_b_supuestos.md \
  --output=../plato_plato_memoria.pdf
