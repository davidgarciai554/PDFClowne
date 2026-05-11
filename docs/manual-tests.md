# Pruebas manuales

## Edicion visual en `01-base.pdf`

1. Abrir `tests/pdfs/01-base.pdf`.
2. Entrar en modo `Editar`.
3. Esperar a que termine el analisis de la pagina.
4. Confirmar que no aparece el aviso `No editable text was found...`.
5. Confirmar que se detectan `DAVID GARCIA MARTIN`,
   `Backend Engineer con experiencia` y
   `HABILIDADES PROFESIONALES Y PERSONALES`.
6. Seleccionar el parrafo `Backend Engineer con experiencia...`.
7. Editar el texto y confirmar que el original queda tapado por la mascara
   temporal durante la escritura.
8. Guardar como copia.
9. Reabrir la copia y confirmar que el cambio visual sigue presente.
10. Repetir con zoom 100%, 150% y 300%, verificando que el overlay no se
    desplaza al hacer scroll.
