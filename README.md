# U1 Liashenko, Ludvík 


# Úloha 1 – JPEG komprese a dekomprese rastru

Implementace JPEG komprese a dekomprese v MATLABu bez vestavěných funkcí, ve třech variantách transformace: DCT, DFT a DWT (Haar).


## Hlavní skripty

jpeg_dct.m komprese s diskrétní kosinovou transformací (základní úloha) 
jpeg_dft.m komprese s diskrétní Fourierovou transformací (bonus) 
jpeg_dwt.m komprese s Haarovou vlnkovou transformací (bonus) 

Každý skript obsahuje celý kompresní řetězec (YCbCr, převzorkování, transformace, kvantizace, ZIG-ZAG, Huffman a zpětný chod) a jako lokální funkce svou transformaci a její inverzi. Seznam testovacích souborů je v proměnné files, faktory komprese v proměnné qs.

## Sdílené funkce

Soubor  Popis 

 resamp_22.m  převzorkování chrominance: průměr bloků 2 × 2 
 inv_resamp_22.m  zpětné zvětšení metodou nejbližšího souseda 
 zigzag_scan.m  převod bloku 8 × 8 na ZIG-ZAG sekvenci 
 zigzag_blocks.m  ZIG-ZAG pro všechny bloky složky rastru 
 inverse_zigzag_blocks.m  zpětné složení bloků ze ZIG-ZAG sekvence 
 huffman_compres.m  Huffmanovo kódování 
 huffman_decompress.m  Huffmanovo dekódování 
 comp_er.m  střední kvadratická odchylka složky 

## Testovací data

Rastry 128 × 128 px ve formátu BMP:
 photo.bmp  barevná fotografie 
 gradient.bmp  barevný gradient 
 mono.bmp  černobílý gradient 
 vector.bmp  rastr z vektorových obrazců (ostré hrany) 

## Výstupní rastry

Složka Výstup obsahuje uložená okna grafů se zobrazením originálu a rekonstrukcí pro q = 10, 50 a 70. Názvy souborů mají tvar <metoda>_<rastr>.png, například dwt_vector.png (metody dct, dft, dwt; rastry photo, gradient, mono, vector). 
