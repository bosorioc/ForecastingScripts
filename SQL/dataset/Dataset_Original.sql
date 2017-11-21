DECLARE @AnioCampanaIni CHAR(6)
DECLARE @AnioCampanaFin CHAR(6)
DECLARE @AnioCampanaIniFuturo CHAR(6)
DECLARE @AnioCampanaFinFuturo CHAR(6)
DECLARE @CodPais CHAR(4)
DECLARE @FlagTest INT
DECLARE @DesCategoria VARCHAR(20)

SET @DesCategoria = 
'CUIDADO PERSONAL'
--'TRATAMIENTO FACIAL'
--'FRAGANCIAS'
--'TRATAMIENTO CORPORAL'
--'MAQUILLAJE'

SET @AnioCampanaIni = '201401'
SET @AnioCampanaFin = '201714'
SET @AnioCampanaIniFuturo = '201715'
SET @AnioCampanaFinFuturo = '201806'

/*Los códigos de país de SICC de El Salvador y Guatemala no tienen un formato bonito*/
SELECT @CodPais = CASE WHEN CodPais = 'S2' THEN 'SV' WHEN CodPais = 'G2' THEN 'GT' ELSE CodPais END
FROM DPais

/*Campañas cerradas: Solo productos que han facturado en la forma de venta catálogo, productos cosméticos y algunos tipos de oferta*/
--DROP TABLE #BASE
SELECT A.AnioCampana, B.CodCUC, A.PKProducto, B.DesMarca, B.CodCategoria, B.DesCategoria, CodTipoOferta, A.PKTipoOferta, 0 AS FlagNoConsiderar,
CASE WHEN CodTipoOferta IN ('007','008','010','011','012','013','014','015','017','018','019','033','036','039','043','044','106','114','116') THEN 1 
ELSE 0 END AS FlagCatalogo,
CASE WHEN CodTipoOferta IN ('003','009','029','035','038','047','048','049','060','064','108','115','123') THEN 1 ELSE 0 END AS FlagRevista,
SUM(RealUUVendidas) AS RealUUVendidas, SUM(RealUUFaltantes) AS RealUUFaltantes, 1 AS FlagReal, CONVERT(FLOAT, 0) AS PrecioNormalMN
INTO #BASE
FROM FVTAPROEBECAMC01 A 
INNER JOIN DPRODUCTO B ON A.PKPRODUCTO = B.PKPRODUCTO 
INNER JOIN DTIPOOFERTA C ON A.PKTipoOferta = C.PKTipoOferta
WHERE A.ANIOCAMPANA BETWEEN @AnioCampanaIni AND @AnioCampanaFin
AND A.ANIOCAMPANA = A.ANIOCAMPANAREF
AND C.CodTipoProfit = '01' --Forma de Venta Catálogo
AND DesUnidadNegocio IN ('COSMETICOS')
AND DESCATEGORIA = @DesCategoria
AND CodTipoOferta IN ('003','007','008','009','010','011','012','013','014','015','017','018','019','029','033',
'035','036','038','039','043','044','047','048','049','060','064','106','108','114','115','116','123')
GROUP BY A.ANIOCAMPANA, B.CODCUC, A.PKProducto, B.DesMarca, B.CodCategoria, B.DesCategoria, CodTipoOferta, A.PKTipoOferta

/*Campañas abiertas: todas las tácticas que han sido ingresadas en Planit y el sistema comercial*/ 
INSERT INTO #BASE
SELECT AnioCampana, CodCUC, A.PKProducto, DesMarca, CodCategoria, DesCategoria, CodTipoOferta, A.PkTipoOferta, 0 AS FlagNoConsiderar,
CASE WHEN CodTipoOferta IN ('007','008','010','011','012','013','014','015','017','018','019','033','036','039','043','044','106','114','116') THEN 1 
ELSE 0 END AS FlagCatalogo,
CASE WHEN CodTipoOferta IN ('003','009','029','035','038','047','048','049','060','064','108','115','123') THEN 1 ELSE 0 END AS FlagRevista,
0 AS RealUUVendidas, 0 AS RealUUFaltantes, 0 AS FlagReal, CONVERT(FLOAT, 0) AS PrecioNormalMN
FROM DMATRIZCAMPANA A INNER JOIN DPRODUCTO B ON A.PKProducto = B.PKProducto
INNER JOIN DTIPOOFERTA C ON A.PKTipoOferta = C.PKTipoOferta
WHERE ANIOCAMPANA BETWEEN @AnioCampanaIniFuturo AND @AnioCampanaFinFuturo 
AND CodTipoProfit = '01'
AND CodTipoOferta IN ('003','007','008','009','010','011','012','013','014','015','017','018','019','029','033',
'035','036','038','039','043','044','047','048','049','060','064','106','108','114','115','116','123')
AND DESCATEGORIA = @DesCategoria

--Precio Normal
--Considerar solo los productos CUC que tienen estimados
SELECT A.AnioCampana, CodCUC, SUM(EstUUVendidas) AS NroEstimados,max(PrecioOfertaDol) as PrecioOfertaDol,  MAX(Case when @codpais = 'BO' then PrecioNormalDol else PrecioNormalMN end) AS PRECIONORMALMN  
INTO #TMP_Estimados
FROM FVTAPROCAMMES A INNER JOIN DPRODUCTO B ON A.PKProducto = B.PKProducto
WHERE A.AnioCampana = A.AnioCampanaRef
AND AnioCampana BETWEEN @AnioCampanaIni AND @AnioCampanaFinFuturo
AND DESCATEGORIA = @DesCategoria
GROUP BY A.AnioCampana, CodCUC

--Precio Oferta Dolares
--Considerar solo los productos CUC que tienen estimados
SELECT A.AnioCampana, CodCUC,PKTipoOferta,max(PrecioOfertaDol) as PrecioOfertaDol  
INTO #TMP_DOLAR
FROM FVTAPROCAMMES A  INNER JOIN DPRODUCTO B ON A.PKProducto = B.PKProducto
WHERE A.AnioCampana = A.AnioCampanaRef
AND AnioCampana BETWEEN @AnioCampanaIni AND @AnioCampanaFinFuturo
AND DESCATEGORIA = @DesCategoria
GROUP BY A.AnioCampana, CodCUC,PKTipoOferta

/*Si un  CUC no tiene unidades estimadas se debe eliminar*/
UPDATE #BASE
SET FlagNoConsiderar = 1
FROM #BASE A INNER JOIN #TMP_estimados B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE NroEstimados = 0 

DELETE FROM #BASE WHERE FlagNoConsiderar = 1

/*Se actualiza el precio normal de cada CUC*/
UPDATE #BASE
SET PrecioNormalMN = B.PRECIONORMALMN
FROM #BASE A INNER JOIN #TMP_Estimados B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC

/*De la matriz de facturación se traen las variables de argumentación y el precio Oferta 
Se debe tomar en cuenta lo siguiente para campañas cerradas:
Forma de Venta: Catálogo
La táctica debe tener registrada la ubicación.
La táctica debe estar diagramada solo en la revista o en los catálogos
El código de Venta debe ser diferente a 00000, este es un código dummy de tácticas que llegan a Sicc desde Planit, pero que no se llegan a activar
El precio de oferta del producto debe ser mayor a 0
*/
SELECT AnioCampana, C.CODCUC, A.PKTipoOferta, B.CodTipoOferta, DesUbicacionCatalogo, DesLadoPag, DesTipoCatalogo,
ISNULL(CONVERT(FLOAT,RIGHT(RTRIM(REPLACE(REPLACE(DesExposicion,'SIN EXPOSICION',''), '%', '')), 4)),0)/100 * NroPaginas  AS Exposicion, 
NroPaginas, MAX(FotoProducto) AS FotoProducto, MAX(FotoModelo) AS FotoModelo, MAX(FlagDiscover) AS FlagDiscover, PaginaCatalogo,
CONVERT(FLOAT, 0) AS PrecioOferta, 1 AS Registros, 1 as Eliminar  into #TMP_DMATRIZCAMPANA
FROM DMATRIZCAMPANA A INNER JOIN DTIPOOFERTA B ON A.PKTIPOOFERTA = B.PKTIPOOFERTA
INNER JOIN DPRODUCTO C ON A.PKPRODUCTO = C.PKPRODUCTO
WHERE AnioCampana BETWEEN @AnioCampanaIni AND @AnioCampanaFin
AND CODTIPOPROFIT = '01'
AND DesUbicacionCatalogo IS NOT NULL 
AND CODVENTA <> '00000'
AND DesTipoCatalogo IN ('REVISTA BELCORP', 'CATALOGO CYZONE', 'CATALOGO EBEL/LBEL', 'CATALOGO ESIKA')
--AND PrecioOferta > 0 
GROUP BY AnioCampana, C.CODCUC, A.PKTipoOferta, B.CodTipoOferta, DesUbicacionCatalogo, DesLadoPag, DesTipoCatalogo, DesExposicion, 
NroPaginas, PaginaCatalogo
UNION
/*Campañas abiertas:
Forma de Venta: Catálogo
La táctica debe estar diagramada solo en la revista o en los catálogos
*/
SELECT AnioCampana, C.CODCUC, A.PKTipoOferta, B.CodTipoOferta, DesUbicacionCatalogo, DesLadoPag, DesTipoCatalogo,
ISNULL(CONVERT(FLOAT,RIGHT(RTRIM(REPLACE(REPLACE(DesExposicion,'SIN EXPOSICION',''), '%', '')), 4)),0)/100 * NroPaginas AS Exposicion, 
NroPaginas, MAX(FotoProducto) AS FotoProducto, MAX(FotoModelo) AS FotoModelo, MAX(FlagDiscover) AS FlagDiscover, PaginaCatalogo,
MIN(PrecioOferta) AS PrecioOferta, 1 AS Registros, 1 as Eliminar 
FROM DMATRIZCAMPANA A INNER JOIN DTIPOOFERTA B ON A.PKTIPOOFERTA = B.PKTIPOOFERTA
INNER JOIN DPRODUCTO C ON A.PKPRODUCTO = C.PKPRODUCTO
WHERE AnioCampana BETWEEN @AnioCampanaIniFuturo AND @AnioCampanaFinFuturo
AND CODTIPOPROFIT = '01'
AND DesTipoCatalogo IN ('REVISTA BELCORP', 'CATALOGO CYZONE', 'CATALOGO EBEL/LBEL', 'CATALOGO ESIKA')
GROUP BY AnioCampana, C.CODCUC, A.PKTipoOferta, B.CodTipoOferta, DesUbicacionCatalogo, DesLadoPag, DesTipoCatalogo, DesExposicion, 
NroPaginas, PaginaCatalogo

/*Se actualiza el precio de Oferta*/
SELECT AnioCampana, C.CODCUC, A.PKTipoOferta, B.CodTipoOferta, MIN(PrecioOferta) AS PrecioOferta 
INTO #TMP_PRECIOOFERTA
FROM DMATRIZCAMPANA A INNER JOIN DTIPOOFERTA B ON A.PKTIPOOFERTA = B.PKTIPOOFERTA
INNER JOIN DPRODUCTO C ON A.PKPRODUCTO = C.PKPRODUCTO
WHERE AnioCampana BETWEEN @AnioCampanaIni AND @AnioCampanaFin
AND CODTIPOPROFIT = '01'
AND CODVENTA <> '00000'
AND DesTipoCatalogo IN ('REVISTA BELCORP', 'CATALOGO CYZONE', 'CATALOGO EBEL/LBEL', 'CATALOGO ESIKA')
AND PrecioOferta > 0 
GROUP BY AnioCampana, C.CODCUC, A.PKTipoOferta, B.CodTipoOferta

UPDATE #TMP_DMATRIZCAMPANA
SET PrecioOferta = B.PrecioOferta
FROM #TMP_DMATRIZCAMPANA A INNER JOIN #TMP_PRECIOOFERTA B ON A.ANIOCAMPANA = B.ANIOCAMPANA AND A.CodCUC = B.CodCUC AND A.CodTipoOferta = B.CodTipoOferta

DELETE #TMP_DMATRIZCAMPANA WHERE PrecioOferta = 0 

/*Se eliminan las tácticas de la revista que están ubicadas en la página 0 o ubicadas en una página mayor a 100, porque normalmente son reacciones*/
DELETE FROM #TMP_DMATRIZCAMPANA
WHERE DesTipoCatalogo IN ('REVISTA BELCORP') AND (ISNULL(PaginaCatalogo,0) = 0 OR  ISNULL(PaginaCatalogo,0)>=100)

/*Agrupamos por producto - tipo de oferta*/
SELECT AnioCampana, CodCUC, PKTipoOferta, MIN(PrecioOferta) AS PrecioOferta, 
SUM(ISNULL(Exposicion,0)) AS Exposicion, SUM(ISNULL(NroPaginas,0)) AS NroPaginas 
INTO #TMP_DMATRIZCAMPANA1
FROM #TMP_DMATRIZCAMPANA
GROUP BY AnioCampana, CodCUC, PKTipoOferta  

/*Agrupamos por CUC - Tipo de Oferta para totalizar las unidades vendidas y las unidades faltantes*/
SELECT ANIOCAMPANA, CODCUC, DesMarca, CodCategoria, DesCategoria, CodTipoOferta, PKTipoOferta, FlagCatalogo, FlagRevista, 
SUM(RealUUVendidas) as RealUUVendidas, SUM(RealUUFaltantes)RealUUFaltantes, FlagReal, CONVERT(FLOAT,0) AS PrecioOferta, 
CONVERT(FLOAT,0) AS Exposicion, AVG(PrecioNormalMN) AS PrecioNormalMN, 0 AS NroPaginas, CONVERT(FLOAT,0) AS Descuento, 0 AS NroPaginasOriginal, 
CONVERT(FLOAT,0) AS ExposicionOriginal, 0 AS FlagDiagramado
INTO #BASE_1
FROM #BASE 
GROUP BY ANIOCAMPANA, CODCUC, DesMarca, CodCategoria, DesCategoria, CodTipoOferta, PKTipoOferta, FlagCatalogo, FlagRevista, FlagReal

/*Por cada CUC - TO se le asigna el precio de oferta, exposición total, número de páginas y descuento*/
UPDATE	#BASE_1
SET	PrecioOferta = B.PrecioOferta,
	Exposicion = B.Exposicion,
	ExposicionOriginal = B.Exposicion,
	NroPaginas = B.NroPaginas,
	NroPaginasOriginal = B.NroPaginas,
	Descuento = CASE WHEN CONVERT(FLOAT, A.PrecioNormalMN) = 0 THEN 0 ELSE (1 - (CONVERT(FLOAT, B.PrecioOferta) /CONVERT(FLOAT, A.PrecioNormalMN))) END,
	FlagDiagramado = 1
FROM #BASE_1 A INNER JOIN #TMP_DMATRIZCAMPANA1 B 
ON A.AnioCampana = B.AnioCampana AND A.CODCUC = B.CODCUC AND A.PKTipoOferta = B.PKTipoOferta 

UPDATE #BASE_1
SET PrecioOferta = B.PrecioOfertaDol
FROM #BASE_1 A INNER JOIN #TMP_DOLAR B
ON A.AnioCampana = B.AnioCampana AND A.CODCUC = B.CODCUC AND A.PKTipoOferta = B.PKTipoOferta 
WHERE @codpais = 'BO'

/*Si no fue diagramado no lo considero*/
/*Si el CUC-TO no fue diagramado lo elimino, es una reacción*/
DELETE FROM #BASE_1 WHERE FlagDiagramado = 0

/*Apoyados
Si lo apoyan menos de 10 productos no se considera el precio */
SELECT AnioCampana, B.CodCUC, D.CodTipoOferta, COUNT(DISTINCT C.CodCUC) AS NroApoyados
INTO #Apoyados
FROM DAPOYOPRODUCTO A INNER JOIN DPRODUCTO B ON A.PKProductoApoyador = B.PKProducto
INNER JOIN DPRODUCTO C ON A.PKProductoApoyado = C.PKProducto
INNER JOIN DTIPOOFERTA D ON A.PKTipoOfertaApoyador = D.PKTipoOferta
WHERE AnioCampana BETWEEN @AnioCampanaIni AND @AnioCampanaFinFuturo
GROUP BY AnioCampana, B.CodCUC, D.CodTipoOferta
HAVING COUNT(DISTINCT C.CodCUC) < 10 

--Si el precio del producto en un TO de set y/0 apoyados es el mínimo entonces considero el promedio con los otros TOs
SELECT AnioCampana, CodCUC, CodTipoOferta, PrecioOferta INTO #TMP_PrecioSets FROM #BASE_1
WHERE CodTipoOferta IN ('008', '035', '036', '060', '049', '012', '038', '039') AND PrecioOferta > 0

SELECT A.AnioCampana, A.CodCUC, A.CodTipoOferta, PrecioOferta 
INTO #Apoyados1
FROM #BASE_1 A 
INNER JOIN #Apoyados B ON A.ANIOCAMPANA = B.ANIOCAMPANA AND A.CODCUC = B.CodCUC

SELECT A.ANIOCAMPANA, A.CODCUC, MIN(A.PrecioOferta) AS PrecioOfertaTotal, MIN(B.PrecioOferta) AS PrecioOfertaSet, 
CASE WHEN MIN(A.PrecioOferta) = MIN(B.PrecioOferta) THEN 1 ELSE 0 END AS FlagPromedio 
INTO #TMP_PromedioSets FROM #BASE_1 A 
INNER JOIN #TMP_PrecioSets B ON A.ANIOCAMPANA = B.ANIOCAMPANA AND A.CODCUC = B.CodCUC
GROUP BY A.ANIOCAMPANA, A.CODCUC
UNION 
SELECT A.ANIOCAMPANA, A.CODCUC, MIN(A.PrecioOferta) AS PrecioOfertaTotal, MIN(B.PrecioOferta) AS PrecioOfertaSet, 
CASE WHEN MIN(A.PrecioOferta) = MIN(B.PrecioOferta) THEN 1 ELSE 0 END AS FlagPromedio 
FROM #BASE_1 A 
INNER JOIN #Apoyados1 B ON A.ANIOCAMPANA = B.ANIOCAMPANA AND A.CODCUC = B.CodCUC
GROUP BY A.ANIOCAMPANA, A.CODCUC

SELECT A.AnioCampana, A.CodCUC, MIN(A.PrecioOferta) AS PrecioOfertaMIN, CONVERT(FLOAT,0) AS PrecioOfertaSet
INTO #TMP_MIN
FROM #BASE_1 A INNER JOIN #TMP_PromedioSets B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC 
WHERE FlagPromedio = 1
GROUP BY A.AnioCampana, A.CodCUC

SELECT A.AnioCampana, A.CodCUC, AVG(PrecioOferta) as PrecioOferta INTO #TMP_Promedio 
FROM #BASE_1 A INNER JOIN #TMP_PromedioSets B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC 
WHERE FlagPromedio = 1
GROUP BY A.AnioCampana, A.CodCUC

UPDATE #TMP_MIN
SET PrecioOfertaSet = B.PrecioOferta
FROM #TMP_MIN A INNER JOIN #TMP_Promedio B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC

UPDATE #BASE_1
SET PrecioOferta = B.PrecioOfertaSet,
	Descuento = CASE WHEN CONVERT(FLOAT, A.PrecioNormalMN) = 0 THEN 0 ELSE (1 - (CONVERT(FLOAT, B.PrecioOfertaSet) /CONVERT(FLOAT, A.PrecioNormalMN))) END
FROM #BASE_1 A 
INNER JOIN #TMP_MIN B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC AND A.PrecioOferta = B.PrecioOfertaMIN

--Si es que el producto no fue diagramado, entonces le coloco los mínimo para no alterar los promedios
--DROP TABLE #SinExposicion
SELECT DISTINCT AnioCampana, CodCUC INTO #SinExposicion FROM #BASE_1 WHERE Exposicion = 0

SELECT A.AnioCampana, A.CodCUC, MIN(Exposicion) AS Exposicion
INTO #ExposicionMinima
FROM #BASE_1 A INNER JOIN #SinExposicion B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE Exposicion > 0
GROUP BY A.AnioCampana, A.CodCUC

UPDATE #BASE_1
SET Exposicion = B.Exposicion
FROM #BASE_1 A INNER JOIN #ExposicionMinima B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE A.Exposicion = 0

SELECT DISTINCT AnioCampana, CodCUC INTO #SinPrecioOferta FROM #BASE_1 WHERE PrecioOferta = 0

SELECT A.AnioCampana, A.CodCUC, MIN(PrecioOferta) AS PrecioOferta, MIN(Descuento) AS Descuento
INTO #PrecioOfertaMinimo
FROM #BASE_1 A INNER JOIN #SinPrecioOferta B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE PrecioOferta > 0
GROUP BY A.AnioCampana, A.CodCUC

UPDATE #BASE_1
SET PrecioOferta = B.PrecioOferta,
	Descuento = B.Descuento
FROM #BASE_1 A INNER JOIN #PrecioOfertaMinimo B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE A.PrecioOferta = 0

SELECT @CodPais AS CodPais,
A.AnioCampana, 
A.DesMarca, 
A.CodCUC,
A.CodCategoria,
A.DesCategoria,
0 AS N_Records_SKU,
0 AS NCampaign,
CASE WHEN A.AnioCampana <= '201710' THEN 1 ELSE 0 END AS Development,
CASE WHEN A.AnioCampana <= @AnioCampanaFin THEN B.RealNroPedidos ELSE 0 END AS RealNroPedidos,
AVG(PrecioOferta) AS PrecioOfertaProm,
MIN(PrecioOferta) AS PrecioOfertaMin,
POWER(MIN(PrecioOferta),2) AS PrecioOfertaMinAlCuadrado,
CASE WHEN MIN(PrecioOferta) = 0 THEN 0 ELSE 1/MIN(PrecioOferta) END AS PrecioOfertaMinInverso,
MAX(PrecioOferta) AS PrecioOfertaMax,
POWER(MAX(PrecioOferta),2) AS PrecioOfertaMaxAlCuadrado,
CASE WHEN MAX(PrecioOferta) = 0 THEN 0 ELSE 1/MAX(PrecioOferta) END AS PrecioOfertaMaxInverso,
AVG(PrecioNormalMN) AS PrecioNormalMN, 
COUNT(DISTINCT PkTipoOferta) AS NroTipoOfertas,
SUM(FlagCatalogo) AS NroTipoOfertasCatalogo,
SUM(FlagRevista) AS NroTipoOfertasRevista,
SUM(RealUUVendidas + RealUUFaltantes) AS RealUUDemandadas, 
CONVERT(FLOAT,SUM(RealUUVendidas + RealUUFaltantes)) /CONVERT(FLOAT,B.RealNroPedidos) AS PUP, 
MIN(Exposicion) AS ExposicionMin,
SQRT(MIN(Exposicion)) AS ExposicionMinRaizCuadrada,
MAX(Exposicion) AS ExposicionMax, 
SQRT(MAX(Exposicion)) AS ExposicionMaxRaizCuadrada,
SUM(ExposicionOriginal) AS ExposicionTotal,
MAX(Descuento) AS MaxDescuento,
POWER(MAX(Descuento),2) AS MaxDescuentoCuadrado,
CASE WHEN MAX(Descuento) > 0.6 THEN 1 ELSE 0 END AS FlagDescuentoMayor60,
CASE WHEN MAX(Descuento) > 0.7 THEN 1 ELSE 0 END AS FlagDescuentoMayor70,
CONVERT(FLOAT, 0) AS MaxDescuentoRevista,
CONVERT(FLOAT, 0) AS MaxDescuentoCatalogo,
CONVERT(FLOAT, 0) AS FactorDemoCatalogo,
0 AS FlagMaxDescuentoRevista,
0 AS UbicacionCaratula, 
0 AS UbicacionContracaratula, 
0 AS UbicacionPoster, 
0 AS UbicacionInserto, 
0 AS UbicacionPrimeraPagina, 
0 AS UbicacionOtros, 
0 AS LadoDerecho, 
0 AS LadoAmbos, 
0 AS LadoIzquierdo, 
NroPaginas = SUM(ISNULL(NroPaginas,0)), 
0 AS FotoProducto,
0 AS FotoModelo, 
0 AS FlagDiscover, 
0 AS FlagTacticaMacro,
0 AS FlagTacticaDetallada,
CASE WHEN RIGHT(A.AnioCampana,2) = '09' THEN 1 ELSE 0 END AS FlagDiaPadre,
CASE WHEN RIGHT(A.AnioCampana,2) = '07' THEN 1 ELSE 0 END AS FlagDiaMadre,
CASE WHEN RIGHT(A.AnioCampana,2) IN ('17', '18') THEN 1 ELSE 0 END AS FlagNavidad,
CASE WHEN RIGHT(A.AnioCampana,2) = '01' THEN 1 ELSE 0 END AS FlagC01,
CASE WHEN RIGHT(A.AnioCampana,2) = '02' THEN 1 ELSE 0 END AS FlagC02,
0 AS FlagRegalo,
0 AS TO_003_OfertaConsultora,
0 AS TO_007_Apoyados,
0 AS TO_008_Especiales,
0 AS TO_011_OfertasPrincipales,
0 AS TO_013_Especiales,
0 AS TO_014_BloquePosterContra,
0 AS TO_015_Especiales,
0 AS TO_017_Especiales,
0 AS TO_018_Especiales,
0 AS TO_019_RestoLinea,
0 AS TO_029_OfertaConsultora,
0 AS TO_033_PromocionPropia,
0 AS TO_035_FechasEspeciales,
0 AS TO_036_FechasEspeciales,
0 AS TO_043_Especiales,
0 AS TO_048_OfertaConsultora,
0 AS TO_049_OfertaConsultora,
0 AS TO_060_OfertaConsultora,
0 AS TO_106_Oferta1x2x3x,
0 AS TO_116_PromocionInsuperable,
0 AS TO_123_OfertaConsultora
INTO #BASE_3
FROM #BASE_1 A INNER JOIN FNUMPEDCAM B ON A.AnioCampana = B.AnioCampana
GROUP BY A.AnioCampana, A.DesMarca, A.CodCUC, A.CodCategoria, A.DesCategoria, B.RealNroPedidos

DELETE FROM #BASE_3 WHERE PrecioOfertaMin = 0

UPDATE #BASE_3
SET UbicacionCaratula = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE ISNULL(DesUbicacionCatalogo,'') IN ('CARATULA', 'CARATULA Y CONTRACARATULA')

UPDATE #BASE_3
SET UbicacionContracaratula = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE ISNULL(DesUbicacionCatalogo,'') IN ('CONTRA CARATULA', 'CARATULA Y CONTRACARATULA') 

UPDATE #BASE_3
SET UbicacionPoster = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE ISNULL(DesUbicacionCatalogo,'') IN ('POSTER')

UPDATE #BASE_3
SET UbicacionInserto = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE ISNULL(DesUbicacionCatalogo,'') IN ('INSERTO')

UPDATE #BASE_3
SET UbicacionPrimeraPagina = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE ISNULL(DesUbicacionCatalogo,'') IN ('PRIMERA PAGINA (2 Y 3)')

UPDATE #BASE_3
SET UbicacionOtros = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE ISNULL(DesUbicacionCatalogo,'') IN ('OTROS / CUALQUIER PAGINA', '')

UPDATE #BASE_3
SET LadoDerecho = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE DesLadoPag = 'LADO DERECHO'

UPDATE #BASE_3
SET LadoAmbos = 1 
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE DesLadoPag = 'EN AMBOS LADOS'

UPDATE #BASE_3
SET LadoIzquierdo = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE DesLadoPag = 'LADO IZQUIERDO'

UPDATE #BASE_3
SET FotoProducto = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.FotoProducto = 'S'

UPDATE #BASE_3
SET FotoModelo = 1 
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.FotoModelo = 'S'

UPDATE #BASE_3
SET FlagDiscover = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE ISNULL(B.FlagDiscover,0) = 1

UPDATE #BASE_3
SET FlagRegalo = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('007', '029', '048')

UPDATE #BASE_3
SET TO_003_OfertaConsultora = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('003')

UPDATE #BASE_3
SET TO_007_Apoyados = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('007')

UPDATE #BASE_3
SET TO_008_Especiales = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('008')

UPDATE #BASE_3
SET TO_011_OfertasPrincipales = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('011')

UPDATE #BASE_3
SET TO_013_Especiales = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('013')

UPDATE #BASE_3
SET TO_014_BloquePosterContra = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('014')

UPDATE #BASE_3
SET TO_015_Especiales = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('015')

UPDATE #BASE_3
SET TO_017_Especiales = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('017')

UPDATE #BASE_3
SET TO_018_Especiales = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('018')

UPDATE #BASE_3
SET TO_019_RestoLinea = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('019')

UPDATE #BASE_3
SET TO_029_OfertaConsultora = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('029')

UPDATE #BASE_3
SET TO_033_PromocionPropia = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('033')

UPDATE #BASE_3
SET TO_035_FechasEspeciales = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('035')

UPDATE #BASE_3
SET TO_036_FechasEspeciales = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('036')

UPDATE #BASE_3
SET TO_043_Especiales = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('043')

UPDATE #BASE_3
SET TO_048_OfertaConsultora = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('048')

UPDATE #BASE_3
SET TO_049_OfertaConsultora = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('049')

UPDATE #BASE_3
SET TO_060_OfertaConsultora = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('060')

UPDATE #BASE_3
SET TO_106_Oferta1x2x3x = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('106')

UPDATE #BASE_3
SET TO_116_PromocionInsuperable = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('116')

UPDATE #BASE_3
SET TO_123_OfertaConsultora = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('123')

UPDATE #BASE_3
SET FlagTacticaMacro = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('001', '003', '004', '005', '006', '009', '010', '011', '012', '013', '014', '025',
 '029', '033', '035', '044', '048', '049', '060', '064', '106', '108', '114', '115', '116', '117', '123') 

UPDATE #BASE_3
SET FlagTacticaDetallada = 1
FROM #BASE_3 A INNER JOIN #TMP_DMATRIZCAMPANA B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.CodTipoOferta IN ('007', '008', '016', '017', '018', '019', '036', '038', '039', '043', '047') 

--DROP TABLE #BASE_DESCUENTO
SELECT ANIOCAMPANA, CODCUC, FlagCatalogo, FlagRevista, MAX(Descuento) AS DescuentoMaximo INTO #BASE_DESCUENTO FROM #BASE_1
GROUP BY ANIOCAMPANA, CODCUC, FlagCatalogo, FlagRevista 

UPDATE #BASE_3
SET MaxDescuentoRevista = CASE WHEN FlagRevista = 1 THEN DescuentoMaximo ELSE 0 END
FROM #BASE_3 A INNER JOIN #BASE_DESCUENTO B  ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE FlagRevista = 1

UPDATE #BASE_3
SET MaxDescuentoCatalogo = CASE WHEN FlagCatalogo = 1 THEN DescuentoMaximo ELSE 0 END
FROM #BASE_3 A INNER JOIN #BASE_DESCUENTO B  ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE FlagCatalogo = 1

UPDATE #BASE_3
SET FactorDemoCatalogo = MaxDescuentoCatalogo * MaxDescuentoRevista,
FlagMaxDescuentoRevista = CASE WHEN MaxDescuentoRevista > MaxDescuentoCatalogo THEN 1 ELSE 0 END   

--DROP TABLE #TMP_CAMPANA
SELECT DISTINCT AnioCampana INTO #TMP_CAMPANA FROM #BASE_3

--DROP TABLE #TMP_CAMPANA1
SELECT AnioCampana, ROW_NUMBER() OVER(ORDER BY AnioCampana ASC) AS Ncampaign INTO #TMP_CAMPANA1 FROM #TMP_CAMPANA

UPDATE #BASE_3
SET Ncampaign = B.Ncampaign
FROM #BASE_3 A INNER JOIN #TMP_CAMPANA1 B ON A.AnioCampana = B.AnioCampana

--DROP TABLE #TMP_CAMPANACUC
SELECT DISTINCT AnioCampana, CodCUC INTO #TMP_CAMPANACUC FROM #BASE_3

--DROP TABLE #TMP_CAMPANACUC1
SELECT AnioCampana, CodCUC, ROW_NUMBER() OVER(PARTITION BY CodCUC ORDER BY AnioCampana ASC) AS N_Records_SKU 
INTO #TMP_CAMPANACUC1 FROM #TMP_CAMPANACUC

UPDATE #BASE_3
SET N_Records_SKU = B.N_Records_SKU
FROM #BASE_3 A INNER JOIN #TMP_CAMPANACUC1 B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
/*Versión original - Fin*/

--INSERT INTO BDDM01.DATAMARTANALITICO.DBO.TMP_Forecasting