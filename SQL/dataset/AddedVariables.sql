/*Promociones*/ -- Considerar el apoyador como producto target
SELECT *,
CAST(null as decimal(12,2)) AS Promociones_PedidoMinimoCampana,
0							AS Promociones_UnidadesApoyadasCat,
0							AS Promociones_UnidadesApoyadasRev,
0							AS Promociones_UnidadesApoyadasTotales,
CAST(0 as decimal(12,2))	AS Promociones_PrecioMinAPoyadoCat,
CAST(0 as decimal(12,2))	AS Promociones_PrecioMinAPoyadoRev,
CAST(0 as decimal(12,2))	AS Promociones_PrecioMinApoyo,
0							AS Promociones_ConSinCondicion 
INTO #BASE_PROMOCIONES
FROM #BASE_3
ORDER BY AnioCampana, CODCUC

--DROP TABLE #DAPOYOPRODUCTO
SELECT A.AnioCampana, b.CodSAP, B.PKProducto, b.CodCUC,CodVentaApoyado, C.CodTipoOferta, C.PKTipoOferta, D.CodSAP 'CodSAPApoyador', 
d.CodCUC 'CodCUCApoyador', a.CodVentaApoyador
INTO #DAPOYOPRODUCTO
FROM DAPOYOPRODUCTO A 
INNER JOIN DPRODUCTO B ON A.PKPRODUCTOAPOYADO = B.PKPRODUCTO
INNER JOIN DTIPOOFERTA  C ON C.PKTIPOOFERTA = A.PKTipoOfertaApoyador
INNER JOIN DPRODUCTO D ON D.PKPRODUCTO = A.PKPRODUCTOAPOYADOR
where a.AnioCampana between @AnioCampanaIni AND @AnioCampanaFin

CREATE INDEX idx_DApoyoProducto ON #DAPOYOPRODUCTO (AnioCampana,PKProducto, CodVentaApoyador, PKTipoOferta)

-- PARA UNIDADES APOYADAS
;With TMP_UNIDADES_APOYADAS as
(
	select A.ANIOCAMPANA, D.CodSAP, D.CodCUC,D.CodTipoOferta, D.CodSAPApoyador,CodCUCApoyador,   
	CASE WHEN D.CodTipoOferta IN ('004', '005', '006', '007', '008', '010', '011', '012', '013', '014', '015', '016', '017', '018', '019',
	'031', '034', '036', '039', '041', '042', '043', '053', '106', '111', '117', '124') THEN A.RealUUVendidas + A.RealUUFaltantes 
	ELSE 0 END AS RealUUDemandadasCat,
	-- '033', '040', '044', '114', '116', 
	CASE WHEN D.CodTipoOferta IN ('001', '003', '024', '025', '029', '032', '035', '037', '038', '046', '047', '048', '049',
	'050', '051', '052', '060', '064', '107', '108', '112', '113', '115', '118', '123') THEN A.RealUUVendidas + A.RealUUFaltantes  ELSE 0 END AS RealUUDemandadasRev
	from FVTAPROCAMMES a
	INNER JOIN DTIPOOFERTA C ON C.PKTipoOferta = A.PKTipoOferta
	INNER JOIN #DAPOYOPRODUCTO D ON A.PKProducto = D.PKProducto AND 
	D.CodCUCApoyador = A.CodVenta AND D.PKTipoOferta = C.PKTipoOferta AND D.AnioCampana = a.AnioCampana
	where a.AnioCampana between '201401' AND '201718'--@AnioCampanaIni AND @AnioCampanaFin 
	and a.AnioCampana = a.AnioCampanaRef and a.RealUUVendidas>0
	and c.CodTipoOferta not in ('030', '040', '051') 
), TOTAL_UNIDADES_APOYADAS as
(
	SELECT ANIOCAMPANA, CodCUCApoyador,
	SUM(RealUUDemandadasCat)RealUUDemandadasCat, SUM(RealUUDemandadasRev)RealUUDemandadasRev
	FROM TMP_UNIDADES_APOYADAS
	GROUP BY ANIOCAMPANA, CodCUCApoyador
)update a 
set a.Promociones_UnidadesApoyadasCat = b.RealUUDemandadasCat,
	a.Promociones_UnidadesApoyadasRev = b.RealUUDemandadasRev,
	a.Promociones_UnidadesApoyadasTotales = b.RealUUDemandadasCat + b.RealUUDemandadasRev
from #BASE_PROMOCIONES a inner join TOTAL_UNIDADES_APOYADAS b on a.aniocampana = b.aniocampana and a.CodCUC = b.CodCUCApoyador

---- PARA PRECIOS	 select * from #DAPOYOPRODUCTO
--DROP TABLE #TMP_PRECIOS_APOYADAS
select A.ANIOCAMPANA, D.CodSAP, D.CodCUC,D.CodTipoOferta, D.CodSAPApoyador,CodCUCApoyador,
CASE WHEN D.CodTipoOferta IN ('004', '005', '006', '007', '008', '010', '011', '012', '013', '014', '015', '016', '017', '018', '019',
'031', '034', '036', '039', '041', '042', '043', '053', '106', '111', '117', '124') THEN A.PrecioOferta 
ELSE 0 END AS PrecioOfertaCat,
CASE WHEN D.CodTipoOferta IN ('001', '003', '024', '025', '029', '032', '035', '037', '038', '046', '047', '048', '049',
'050', '051', '052', '060', '064', '107', '108', '112', '113', '115', '118', '123') THEN A.PrecioOferta  ELSE 0 END AS PrecioOfertaRev
INTO #TMP_PRECIOS_APOYADAS
from DMATRIZCAMPANA a
INNER JOIN DPRODUCTO B ON A.PKPRODUCTO = B.PKPRODUCTO
INNER JOIN DTIPOOFERTA C ON C.PKTipoOferta = A.PKTipoOferta
INNER JOIN #DAPOYOPRODUCTO D ON D.CodSAP = B.CodSAP AND D.CodCUCApoyador = A.CodVenta AND D.CodTipoOferta = C.CodTipoOferta and a.AnioCampana = d.AnioCampana
where a.AnioCampana between @AnioCampanaIni AND @AnioCampanaFin 
and c.CodTipoProfit = '01'

--DROP TABLE #TOTAL_Precios_APOYADAS
SELECT ANIOCAMPANA, CodCUCApoyador,
Min(case when PrecioOfertaCat= 0 then null else PrecioOfertaCat end) PrecioOfertaCat, 
Min(case when PrecioOfertaRev= 0 then null else PrecioOfertaRev end)PrecioOfertaRev
		into #TOTAL_Precios_APOYADAS
FROM #TMP_PRECIOS_APOYADAS
GROUP BY ANIOCAMPANA, CodCUCApoyador

UPDATE a 
set a.Promociones_PrecioMinAPoyadoCat = b.PrecioOfertaCat,
	a.Promociones_PrecioMinAPoyadoRev = b.PrecioOfertaRev,
	a.Promociones_PrecioMinApoyo = case when b.PrecioOfertaCat <=  b.PrecioOfertaRev then b.PrecioOfertaCat when b.PrecioOfertaRev <= b.PrecioOfertaCat then b.PrecioOfertaRev  End
from #BASE_PROMOCIONES a inner join #TOTAL_Precios_APOYADAS b on a.aniocampana = b.aniocampana and a.CodCUC = b.CodCUCApoyado

--DROP TABLE #APOYO_CONDICION
select AnioCampana, CodCUCApoyador,  
case when CodTipoOferta in ('033','009') then 0 else 1 end Indicador
into #APOYO_CONDICION
from #DAPOYOPRODUCTO where aniocampana < '201614' 

--DROP TABLE #APOYO_CONDICION_TOTAL
SELECT AnioCampana, CodCUCApoyado, sum(Indicador) Indicador into #APOYO_CONDICION_TOTAL from #APOYO_CONDICION group by AnioCampana, CodCUCApoyado order by 1,2

--DROP TABLE #APOYO_CONDICION_GRUPO
select AnioCampana, CodCUCApoyado, case when Indicador > 0 then 1 else 0 End  Indicador into #APOYO_CONDICION_GRUPO from #APOYO_CONDICION_TOTAL

update a 
set a.Promociones_ConSinCondicion = b.Indicador
from #BASE_PROMOCIONES a inner join #APOYO_CONDICION_GRUPO b on a.aniocampana = b.aniocampana and a.CodCUC = b.CodCUCApoyado
where a.aniocampana < '201614'

-- >= a 201614
--DROP TABLE #APOYO_CONDICION_v2
select a.aniocampana, b.codcuc,
case 
when d.codtipooferta in ('116') then 0
when d.codtipooferta in ('009','033','114') then 1 else 0
end 'Indicador'
	into  #APOYO_CONDICION_v2
from #BASE_PROMOCIONES a
inner join dproducto b on a.codCUC = b.codCUC
inner join dmatrizcampana c on c.aniocampana = a.aniocampana and c.PKProducto = b.PKProducto
inner join dtipooferta d on d.PKTipoOferta = c.PKTipoOferta
and a.aniocampana >= '201614'

--DROP TABLE #TOTAL_APOYO_CONDICION_GRUPO_V2
select aniocampana,codcuc, sum(Indicador)Indicador  into #TOTAL_APOYO_CONDICION_GRUPO_V2  from #APOYO_CONDICION_v2 group by aniocampana,codcuc order by 1,2

--DROP TABLE #APOYO_CONDICION_GRUPO_V2
select aniocampana,codcuc, case when Indicador > 0 then 1 else 0 end Indicador into #APOYO_CONDICION_GRUPO_V2  from #TOTAL_APOYO_CONDICION_GRUPO_V2 order by 1,2

update a 
set a.Promociones_ConSinCondicion = b.Indicador
from #BASE_PROMOCIONES a inner join #APOYO_CONDICION_GRUPO_V2 b on a.aniocampana = b.aniocampana and a.CodCUC = b.codcuc
where a.aniocampana >= '201614'

update a 
set a.Promociones_PedidoMinimoCampana = b.PedidoMinMN
from #BASE_PROMOCIONES a inner join FNUMPEDCAM b on a.aniocampana = b.aniocampana 

/*Niveles*/
SELECT *,
0 AS Niveles_FlagApoyoPuntual,
0 AS Niveles_TipoApoyoPuntual,
SPACE(15) AS Niveles_FactorRango,
0 AS Niveles_NroNiveles,
0 AS Niveles_NroNivelesconRegalo,
CONVERT(FLOAT,0) AS Niveles_ExigenciaMinimaconRegalo,
CONVERT(FLOAT,0) AS Niveles_ExigenciaMaximaconRegalo,
CONVERT(FLOAT,0) AS Niveles_GananciaDifPrecioCatalogo,
CONVERT(FLOAT,0) AS Niveles_GananciaMinimaRegalos,
CONVERT(FLOAT,0) AS Niveles_GananciaMaximaRegalos,
CONVERT(FLOAT,0) AS Niveles_RatioGananciaMinimo,
CONVERT(FLOAT,0) AS Niveles_RatioGananciaMaximo,
CONVERT(FLOAT,0) AS Niveles_GratisTopPrimerNivelRegalos,
CONVERT(FLOAT,0) AS Niveles_GratisTopUltimoNivelRegalos,
0 AS Niveles_ConcursosTops,
CONVERT(FLOAT,0) AS Niveles_PrecioMinimoProductoOferta,
CONVERT(FLOAT,0) AS Niveles_CantidadProductosConcurso,
CONVERT(FLOAT,0) AS Niveles_GratisTerceros
INTO #BASE_NIVELES
FROM #BASE_PROMOCIONES

--DROP TABLE #ForDigitacionNivelesPais
SELECT * INTO #ForDigitacionNivelesPais FROM BDDM01.DATAMARTANALITICO.DBO.ForDigitacionNiveles
WHERE CodPais = @CodPais 

UPDATE #BASE_NIVELES
SET Niveles_FactorRango = B.Tipo
FROM #BASE_NIVELES A INNER JOIN #ForDigitacionNivelesPais B ON A.ANIOCAMPANA = B.AnioCampana AND A.CodCUC = B.CODCUC

--DROP TABLE #TMP_ApoyoNiveles
SELECT F.AnioCampana, F.CodCUC, COUNT(DISTINCT G.CodCUC) AS NroApoyados, AVG(PrecioOferta) as PrecioOfertaApoyador
INTO #TMP_ApoyoNiveles
FROM DAPOYOPRODUCTO A INNER JOIN DPRODUCTO C ON A.PKProductoApoyado = C.PKProducto
INNER JOIN DPRODUCTO G ON A.PKProductoApoyador = G.PKProducto
INNER JOIN DMATRIZCAMPANA B ON A.AnioCampana = B.ANIOCAMPANA AND A.CodVentaApoyador = B.CodVenta
INNER JOIN DTIPOOFERTA D ON A.PKTipoOfertaApoyado = D.PKTipoOferta
INNER JOIN #BASE_NIVELES F ON A.AnioCampana = F.AnioCampana AND C.CodCUC = F.CodCUC
WHERE DESTIPOCATALOGO LIKE '%CATALOGO%' AND Niveles_FactorRango <> ''
GROUP BY F.AnioCampana, F.CodCUC

UPDATE #BASE_NIVELES
SET Niveles_FlagApoyoPuntual = 1,
	Niveles_TipoApoyoPuntual = CASE WHEN PrecioOfertaApoyador = 0 THEN 2 ELSE 1 END
FROM #BASE_NIVELES A INNER JOIN #TMP_ApoyoNiveles B ON A.ANIOCAMPANA = B.AnioCampana AND A.CodCUC = B.CODCUC

--DROP TABLE #Niveles
SELECT DISTINCT AnioCampana, IdOferta, CodCUC, RangoInferior, RangoSuperior INTO #Niveles
FROM #ForDigitacionNivelesPais

--DROP TABLE #NroNiveles
SELECT AnioCampana, IdOferta, CODCUC, COUNT(*) AS NroNiveles INTO #NroNiveles FROM #Niveles GROUP BY AnioCampana, IdOferta, CODCUC

--DROP TABLE #NivelesconGratis
SELECT DISTINCT AnioCampana, IdOferta, CodCUC, RangoInferior, RangoSuperior INTO #NivelesconGratis
FROM #ForDigitacionNivelesPais
WHERE ISNULL(CODCUCGratis, '') <> ''

--DROP TABLE #NroNivelesconGratis
SELECT AnioCampana, IdOferta, CODCUC, COUNT(*) AS NroNiveles, MIN(RangoInferior) as MinRangoInferior, MAX(RangoInferior) AS MaxRangoInferior
INTO #NroNivelesconGratis FROM #NivelesconGratis GROUP BY AnioCampana, IdOferta, CODCUC

UPDATE #BASE_NIVELES
SET Niveles_NroNiveles = B.NroNiveles
FROM #BASE_NIVELES A INNER JOIN #NroNiveles B ON A.ANIOCAMPANA = B.AnioCampana AND A.CodCUC = B.CODCUC

UPDATE #BASE_NIVELES
SET Niveles_NroNivelesconRegalo = B.NroNiveles
FROM #BASE_NIVELES A INNER JOIN #NroNivelesconGratis B ON A.ANIOCAMPANA = B.AnioCampana AND A.CodCUC = B.CODCUC

--DROP TABLE #Nivel1
SELECT AnioCampana, IdOferta, CodCUC, AVG(PrecioCatalogo) AS PrecioCatalogo1erNivel, AVG(PrecioUnitario) AS PrecioUnitario1erNivel
INTO #Nivel1
FROM #ForDigitacionNivelesPais
WHERE RangoInferior = 1
GROUP BY AnioCampana, IdOferta, CodCUC

UPDATE #BASE_NIVELES
SET Niveles_GananciaDifPrecioCatalogo = (B.PrecioCatalogo1erNivel - B.PrecioUnitario1erNivel)
FROM #BASE_NIVELES A INNER JOIN #Nivel1 B ON A.ANIOCAMPANA = B.AnioCampana AND A.CodCUC = B.CODCUC

--DROP TABLE #TMP_ExigenciaMinima
SELECT A.AnioCampana, A.IdOferta, A.CODCUC, MAX(PrecioUnitario) AS MinPrecioUnitario, MAX(PrecioCatalogo) AS MinPrecioCatalogo, CONVERT(FLOAT,B.MinRangoInferior) AS MinRangoInferior, 
SUM(CONVERT(FLOAT,ISNULL(NroUnidadesGratis,0)) * CONVERT(FLOAT, ISNULL(ValorizadoGratis,0))) AS ValorizadoGratisMin, SUM(FlagTopGratis) AS TopGratisMin
INTO #TMP_ExigenciaMinima FROM #ForDigitacionNivelesPais A 
INNER JOIN #NroNivelesconGratis B ON A.ANIOCAMPANA = B.ANIOCAMPANA AND A.IdOferta = B.IdOferta AND A.CODCUC = B.CODCUC AND A.RangoInferior = B.MinRangoInferior
GROUP BY A.AnioCampana, A.IdOferta, A.CODCUC, B.MinRangoInferior

--DROP TABLE #TMP_ExigenciaMaxima
SELECT A.AnioCampana, A.IdOferta, A.CODCUC, MAX(PrecioUnitario) AS MaxPrecioUnitario, MAX(PrecioCatalogo) AS MaxPrecioCatalogo, CONVERT(FLOAT,B.MaxRangoInferior) AS MaxRangoInferior,
SUM(CONVERT(FLOAT,ISNULL(NroUnidadesGratis,0)) * CONVERT(FLOAT, ISNULL(ValorizadoGratis,0))) AS ValorizadoGratisMax, SUM(FlagTopGratis) AS TopGratisMax
INTO #TMP_ExigenciaMaxima FROM #ForDigitacionNivelesPais A 
INNER JOIN #NroNivelesconGratis B ON A.ANIOCAMPANA = B.ANIOCAMPANA AND A.IdOferta = B.IdOferta AND A.CODCUC = B.CODCUC AND A.RangoInferior = B.MaxRangoInferior
GROUP BY A.AnioCampana, A.IdOferta, A.CODCUC, B.MaxRangoInferior

UPDATE #BASE_NIVELES
SET Niveles_ExigenciaMinimaconRegalo = (B.MinRangoInferior * B.MinPrecioUnitario),
	Niveles_GananciaMinimaRegalos = ((B.MinRangoInferior * B.MinPrecioCatalogo) - (B.MinRangoInferior * B.MinPrecioUnitario))  + ValorizadoGratisMin,
	Niveles_RatioGananciaMinimo = (((B.MinRangoInferior * B.MinPrecioCatalogo) - (B.MinRangoInferior * B.MinPrecioUnitario))  + ValorizadoGratisMin) / (B.MinRangoInferior * B.MinPrecioUnitario),
	Niveles_GratisTopPrimerNivelRegalos = CASE WHEN TopGratisMin >=1 THEN 1 ELSE 0 END
FROM #BASE_NIVELES A INNER JOIN #TMP_ExigenciaMinima B ON A.ANIOCAMPANA = B.AnioCampana AND A.CodCUC = B.CODCUC

UPDATE #BASE_NIVELES
SET Niveles_ExigenciaMaximaconRegalo = (B.MaxRangoInferior * B.MaxPrecioUnitario),
	Niveles_GananciaMaximaRegalos = ((B.MaxRangoInferior * B.MAXPrecioCatalogo) - (B.MaxRangoInferior * B.MaxPrecioUnitario))  + ValorizadoGratisMax,
	Niveles_RatioGananciaMaximo = (((B.MaxRangoInferior * B.MAXPrecioCatalogo) - (B.MaxRangoInferior * B.MaxPrecioUnitario))  + ValorizadoGratisMax) / (B.MaxRangoInferior * B.MaxPrecioUnitario),
	Niveles_GratisTopUltimoNivelRegalos = CASE WHEN TopGratisMax >=1 THEN 1 ELSE 0 END
FROM #BASE_NIVELES A INNER JOIN #TMP_ExigenciaMaxima B ON A.ANIOCAMPANA = B.AnioCampana AND A.CodCUC = B.CODCUC

--DROP TABLE #GratisTercero
SELECT AnioCampana, IdOferta, CODCUC, FlagTop, SUM(FlagGratisTercero) AS NroGratisTercero 
INTO #GratisTercero
FROM #ForDigitacionNivelesPais GROUP BY AnioCampana, IdOferta, CODCUC, FlagTop

UPDATE #BASE_NIVELES
SET Niveles_GratisTerceros = CASE WHEN NroGratisTercero >=1 THEN 1 ELSE 0 END
FROM #BASE_NIVELES A INNER JOIN #GratisTercero B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC

--DROP TABLE #TMP_PreConcurso
SELECT AnioCampana, IdOferta, codcuc, FlagTop, MAX(PrecioUnitario) AS PrecioUnitario INTO #TMP_PreConcurso from #ForDigitacionNivelesPais
GROUP BY AnioCampana, IdOferta, codcuc, FlagTop

--DROP TABLE #TMP_Concurso
SELECT AnioCampana, IdOferta, COUNT(*) AS NroProductosConcurso, SUM(FlagTop) AS NroProductosTop, MIN(PrecioUnitario) AS PrecioUnitario 
INTO #TMP_Concurso
FROM #TMP_PreConcurso
GROUP BY AnioCampana, IdOferta
HAVING COUNT(*) > 1

--DROP TABLE #TMP_ConcursoResultados
SELECT A.ANIOCAMPANA, A.CODCUC, CASE WHEN NroProductosTop - FlagTop = 0 THEN  0 ELSE 1 END AS ConcursaconTop, NroProductosConcurso, PrecioUnitario
INTO #TMP_ConcursoResultados
FROM #GratisTercero A INNER JOIN #TMP_Concurso B ON A.AnioCampana = B.AnioCampana AND A.IdOferta = B.IdOferta

UPDATE #BASE_NIVELES
SET Niveles_ConcursosTops = B.ConcursaconTop,
	Niveles_PrecioMinimoProductoOferta = B.PrecioUnitario,
	Niveles_CantidadProductosConcurso = B.NroProductosConcurso
FROM #BASE_NIVELES A INNER JOIN #TMP_ConcursoResultados B ON A.AnioCampana = B.AnioCampana AND A.CODCUC = B.CODCUC

/*Sets, por ahora solo para Perú*/
SELECT *,
0 AS FlagSet,
0 AS Set_NroComponentes,
CONVERT(FLOAT,0) AS Set_PrecioNormalTotal,
CONVERT(FLOAT,0) AS Set_PrecioOfertaTotalCatalogo,
CONVERT(FLOAT,0) AS Set_PrecioOfertaTotalRevista,
CONVERT(FLOAT,0) AS Set_DescuentoTotalCatalogo,
CONVERT(FLOAT,0) AS Set_DescuentoTotalRevista,
0 AS Set_FlagFragancias,
0 AS Set_FlagCuidadoPersonal,
0 AS Set_FlagTratamientoCorporal,
0 AS Set_FlagTratamientoFacial,
0 AS Set_FlagMaquillaje,
0 AS Set_FlagExtensionLinea,
0 AS Set_IncluyeBolsa,
0 AS Set_ComponenteTop
INTO #BASE_SETS
FROM #BASE_NIVELES

--Data gratis para eliminar - Inicio
--DROP TABLE #TMP_ForPlanitSets
SELECT * INTO #TMP_ForPlanitSets FROM BDDM01.DATAMARTANALITICO.DBO.ForPlanitSets WHERE CODPAIS = 'PE'
DELETE FROM #TMP_ForPlanitSets WHERE CODTIPOOFERTA = '040' 

--DROP TABLE #TMP_ELIMINARSETS
SELECT A.CodPais, A.AnioCampana, A.DescripcionCatalogo, A.CodEstrategia, A.NroOferta, COUNT(*) AS Componentes 
INTO #TMP_ELIMINARSETS
FROM #TMP_ForPlanitSets A
WHERE CodEstrategia = '002'
GROUP BY A.CodPais, A.AnioCampana, A.DescripcionCatalogo, A.CodEstrategia, A.NroOferta
HAVING COUNT(*)=1

INSERT #TMP_ELIMINARSETS
SELECT A.CodPais, A.AnioCampana, A.DescripcionCatalogo, A.CodEstrategia, A.NroOferta, COUNT(distinct NroGrupo) AS Componentes FROM #TMP_ForPlanitSets A
WHERE CodEstrategia = '003'
GROUP BY A.CodPais, A.AnioCampana, A.DescripcionCatalogo, A.CodEstrategia, A.NroOferta
HAVING COUNT(distinct NroGrupo) = 1

UPDATE #TMP_ForPlanitSets 
SET FlagEliminar = 1
FROM #TMP_ForPlanitSets A 
INNER JOIN #TMP_ELIMINARSETS B ON A.CodPais = B.CodPais AND A.AnioCampana = B.AnioCampana AND 
A.DescripcionCatalogo = B.DescripcionCatalogo AND A.CodEstrategia = B.CodEstrategia AND A.NroOferta = B.NroOferta

DELETE FROM #TMP_ForPlanitSets WHERE FlagEliminar = 1

--Data gratis para eliminar - Fin

--DROP TABLE #DATA_SETS
SELECT A.*, B.CodCUC, B.DesCategoria, B.PKProducto,
CASE WHEN B.DesCategoria = 'FRAGANCIAS' THEN 1 ELSE 0 END AS FlagFragancias, 
CASE WHEN B.DesCategoria = 'CUIDADO PERSONAL' THEN 1 ELSE 0 END AS FlagCuidadoPersonal, 
CASE WHEN B.DesCategoria = 'TRATAMIENTO CORPORAL' THEN 1 ELSE 0 END AS FlagTratamientoCorporal, 
CASE WHEN B.DesCategoria = 'TRATAMIENTO FACIAL' THEN 1 ELSE 0 END AS FlagTratamientoFacial, 
CASE WHEN B.DesCategoria = 'MAQUILLAJE' THEN 1 ELSE 0 END AS FlagMaquillaje,
0 AS FlagTop,
CASE WHEN RIGHT(AnioCampana,2)<=6 THEN CONVERT(VARCHAR(4),LEFT(AnioCampana,4)-1)+' III' 
WHEN RIGHT(AnioCampana,2) BETWEEN 7 AND 12 THEN LEFT(AnioCampana,4)+' I' 
ELSE LEFT(AnioCampana,4)+' II' END AS PeriodoTop
INTO #DATA_SETS FROM #TMP_ForPlanitSets A 
INNER JOIN DPRODUCTO B ON A.CodPais = B.CodPais AND A.CodSAP = B.CodSAP
WHERE A.CodPais = 'PE'

--DROP TABLE #SetsValidos
SELECT DISTINCT A.CodPais, A.AnioCampana, A.DescripcionCatalogo, A.CodEstrategia, A.NroOferta
INTO #SetsValidos
FROM #DATA_SETS A INNER JOIN #BASE_3 B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC

/*Productos Top - Inicio*/
--DROP TABLE #TMP_ProductosTop
SELECT Periodo, DesMarca, DesCategoria, CodCUC, SUM(RealUUVendidas) AS RealUUVendidas, 
RANK() OVER (PARTITION BY Periodo, DesMarca, DesCategoria ORDER BY SUM(RealUUVendidas) DESC) AS Ranking
INTO #TMP_ProductosTop
FROM FVTAPROEBECAMC01 A INNER JOIN DPRODUCTO B ON A.PKPRODUCTO = B.PKPRODUCTO
INNER JOIN DTIEMPOCAMPANA C ON A.AnioCampana = C.AnioCampana
WHERE A.AnioCampana = A.AnioCampanaRef AND A.AnioCampana BETWEEN dbo.CalculaAnioCampana(@AnioCampanaIni, -7) AND @AnioCampanaFin
AND DesCategoria IN ('FRAGANCIAS', 'MAQUILLAJE', 'CUIDADO PERSONAL', 'TRATAMIENTO CORPORAL', 'TRATAMIENTO FACIAL')
GROUP BY Periodo, DesMarca, DesCategoria, CodCUC
ORDER BY  Periodo, DesMarca, DesCategoria, SUM(RealVtaMNNeto) DESC

DELETE FROM #TMP_ProductosTop WHERE Ranking > 10

UPDATE #DATA_SETS
SET FlagTop = 1 
FROM #DATA_SETS A INNER JOIN #TMP_ProductosTop B ON A.CodCUC = B.CodCUC AND A.PeriodoTop = B.Periodo

/*Productos Top - Fin*/

/*Compuesta fija*/
--DROP TABLE #TMP_SetsCompuestaFija
SELECT A.CodPais, A.AnioCampana, A.DescripcionCatalogo, A.CodEstrategia, A.NroOferta, 
SUM(Factor) AS NroComponentes,
SUM(PrecioContable) as PrecioNormalSet,
SUM(PrecioCatalogo) as PrecioOfertaSet, 
CASE WHEN SUM(PrecioContable) = 0 THEN 0 ELSE
(1 - (CONVERT(FLOAT, SUM(PrecioCatalogo))) /CONVERT(FLOAT, SUM(PrecioContable))) END AS DescuentoSet,
CASE WHEN SUM(FlagFragancias)>= 1 THEN 1 ELSE 0 END AS FlagFragancias, 
CASE WHEN SUM(FlagCuidadoPersonal)>= 1 THEN 1 ELSE 0 END AS FlagCuidadoPersonal,
CASE WHEN SUM(FlagTratamientoCorporal)>= 1 THEN 1 ELSE 0 END AS FlagTratamientoCorporal, 
CASE WHEN SUM(FlagTratamientoFacial)>= 1 THEN 1 ELSE 0 END AS FlagTratamientoFacial,
CASE WHEN SUM(FlagMaquillaje)>= 1 THEN 1 ELSE 0 END AS FlagMaquillaje,
CASE WHEN SUM(FlagBolsa)>= 1 THEN 1 ELSE 0 END AS FlagBolsa,
CASE WHEN SUM(FlagTop)>= 1 THEN 1 ELSE 0 END AS FlagTop
INTO #TMP_SetsCompuestaFija
FROM #DATA_SETS A 
INNER JOIN #SetsValidos B ON A.CodPais = B.CodPais AND A.AnioCampana = B.AnioCampana AND A.DescripcionCatalogo = B.DescripcionCatalogo
AND A.CodEstrategia = B.CodEstrategia AND A.NroOferta = B.NroOferta 
WHERE A.CodEstrategia = '002'
GROUP BY A.CodPais, A.AnioCampana, A.DescripcionCatalogo, A.CodEstrategia, A.NroOferta

--DROP TABLE #TMP_SETS
SELECT A.CodPais, A.AnioCampana, A.DescripcionCatalogo, A.CodEstrategia, A.DesEstrategia, A.NroOferta, A.NroPagina, A.CodSAP, A.CodVenta, 
A.CodVentaPadre, A.DesProducto, A.CodTipoOferta, A.PrecioCatalogo, A.PrecioContable, A.PrecioUnitario, A.Factor, A.Grupo, A.NroGrupo,
A.IndicadordeCuadre, A.FactorCuadre, A.IndicadorCuadreGrupo, A.FactorCuadreGrupo, A.FlagEliminar, A.CodCUC, A.DesCategoria, A.PeriodoTop,
B.NroComponentes, B.PrecioNormalSet, B.PrecioOfertaSet, B.DescuentoSet, B.FlagFragancias, B.FlagCuidadoPersonal, B.FlagTratamientoCorporal,
B.FlagTratamientoFacial, B.FlagMaquillaje, B.FlagBolsa, B.FlagTop
INTO #TMP_SETS
FROM #DATA_SETS A INNER JOIN #TMP_SetsCompuestaFija B 
ON A.CodPais = B.CodPais AND A.AnioCampana = B.AnioCampana AND A.DescripcionCatalogo = B.DescripcionCatalogo
AND A.CodEstrategia = B.CodEstrategia AND A.NroOferta = B.NroOferta 

--DROP TABLE #TMP_SetVariable
SELECT A.CodPais, A.AnioCampana, A.DescripcionCatalogo, A.CodEstrategia, A.NroOferta, A.Grupo, AVG(PrecioCatalogo) as PrecioOfertaGrupo, 
AVG(PrecioContable) AS PrecioNormalGrupo, AVG(FactorCuadreGrupo) AS FactorCuadreGrupo, 
CASE WHEN SUM(FlagFragancias)>= 1 THEN 1 ELSE 0 END AS FlagFragancias, 
CASE WHEN SUM(FlagCuidadoPersonal)>= 1 THEN 1 ELSE 0 END AS FlagCuidadoPersonal,
CASE WHEN SUM(FlagTratamientoCorporal)>= 1 THEN 1 ELSE 0 END AS FlagTratamientoCorporal, 
CASE WHEN SUM(FlagTratamientoFacial)>= 1 THEN 1 ELSE 0 END AS FlagTratamientoFacial,
CASE WHEN SUM(FlagMaquillaje)>= 1 THEN 1 ELSE 0 END AS FlagMaquillaje,
CASE WHEN SUM(FlagBolsa)>= 1 THEN 1 ELSE 0 END AS FlagBolsa,
CASE WHEN SUM(FlagTop)>= 1 THEN 1 ELSE 0 END AS FlagTop
INTO #TMP_SetVariable
FROM #DATA_SETS A 
INNER JOIN #SetsValidos B ON A.CodPais = B.CodPais AND A.AnioCampana = B.AnioCampana AND A.DescripcionCatalogo = B.DescripcionCatalogo
AND A.CodEstrategia = B.CodEstrategia AND A.NroOferta = B.NroOferta 
WHERE A.CodEstrategia = '003'
GROUP BY A.CodPais, A.AnioCampana, A.DescripcionCatalogo, A.CodEstrategia, A.NroOferta, A.Grupo

--DROP TABLE #TMP_SetsCompuestaVariable
SELECT A.CodPais, A.AnioCampana, A.DescripcionCatalogo, A.CodEstrategia, A.NroOferta, 
SUM(FactorCuadreGrupo) AS NroComponentes,
SUM(PrecioNormalGrupo) as PrecioNormalSet,
SUM(PrecioOfertaGrupo) as PrecioOfertaSet, 
CASE WHEN SUM(PrecioNormalGrupo) = 0 THEN 0 ELSE 
(1 - (CONVERT(FLOAT, SUM(PrecioOfertaGrupo))) /CONVERT(FLOAT, SUM(PrecioNormalGrupo))) END AS DescuentoSet,
CASE WHEN SUM(FlagFragancias)>= 1 THEN 1 ELSE 0 END AS FlagFragancias, 
CASE WHEN SUM(FlagCuidadoPersonal)>= 1 THEN 1 ELSE 0 END AS FlagCuidadoPersonal,
CASE WHEN SUM(FlagTratamientoCorporal)>= 1 THEN 1 ELSE 0 END AS FlagTratamientoCorporal, 
CASE WHEN SUM(FlagTratamientoFacial)>= 1 THEN 1 ELSE 0 END AS FlagTratamientoFacial,
CASE WHEN SUM(FlagMaquillaje)>= 1 THEN 1 ELSE 0 END AS FlagMaquillaje,
CASE WHEN SUM(FlagBolsa)>= 1 THEN 1 ELSE 0 END AS FlagBolsa,
CASE WHEN SUM(FlagTop)>= 1 THEN 1 ELSE 0 END AS FlagTop
INTO #TMP_SetsCompuestaVariable
FROM #TMP_SetVariable A 
GROUP BY A.CodPais, A.AnioCampana, A.DescripcionCatalogo, A.CodEstrategia, A.NroOferta

INSERT INTO #TMP_SETS
SELECT A.CodPais, A.AnioCampana, A.DescripcionCatalogo, A.CodEstrategia, A.DesEstrategia, A.NroOferta, A.NroPagina, A.CodSAP, A.CodVenta, 
A.CodVentaPadre, A.DesProducto, A.CodTipoOferta, A.PrecioCatalogo, A.PrecioContable, A.PrecioUnitario, A.Factor, A.Grupo, A.NroGrupo,
A.IndicadordeCuadre, A.FactorCuadre, A.IndicadorCuadreGrupo, A.FactorCuadreGrupo, A.FlagEliminar, A.CodCUC, A.DesCategoria, A.PeriodoTop,
B.NroComponentes, B.PrecioNormalSet, B.PrecioOfertaSet, B.DescuentoSet, B.FlagFragancias, B.FlagCuidadoPersonal, B.FlagTratamientoCorporal,
B.FlagTratamientoFacial, B.FlagMaquillaje, B.FlagBolsa, B.FlagTop
FROM #DATA_SETS A INNER JOIN #TMP_SetsCompuestaVariable B 
ON A.CodPais = B.CodPais AND A.AnioCampana = B.AnioCampana AND A.DescripcionCatalogo = B.DescripcionCatalogo
AND A.CodEstrategia = B.CodEstrategia AND A.NroOferta = B.NroOferta 

UPDATE #BASE_SETS
SET FlagSet = 1,
	Set_NroComponentes = B.NroComponentes,
	Set_PrecioNormalTotal = B.PrecioNormalSet,
	Set_PrecioOfertaTotalCatalogo = 0,
	Set_PrecioOfertaTotalRevista = B.PrecioOfertaSet,
	Set_DescuentoTotalCatalogo = 0,
	Set_DescuentoTotalRevista = B.DescuentoSet,
	Set_FlagFragancias = B.FlagFragancias,
	Set_FlagCuidadoPersonal = B.FlagCuidadoPersonal,
	Set_FlagTratamientoCorporal = B.FlagTratamientoCorporal,
	Set_FlagTratamientoFacial = B.FlagTratamientoFacial,
	Set_FlagMaquillaje = B.FlagMaquillaje,
	Set_FlagExtensionLinea = 0,
	Set_IncluyeBolsa = B.FlagBolsa,
	Set_ComponenteTop = B.FlagTop
FROM #BASE_SETS A INNER JOIN #TMP_SETS B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.DescripcionCatalogo IN ('24 - REVISTA BELCORP')

UPDATE #BASE_SETS
SET FlagSet = 1,
	Set_NroComponentes = CASE WHEN B.NroComponentes > 0 THEN B.NroComponentes ELSE Set_NroComponentes END,
	Set_PrecioNormalTotal = CASE WHEN B.PrecioNormalSet > 0 THEN B.PrecioNormalSet ELSE Set_PrecioNormalTotal END,
	Set_PrecioOfertaTotalCatalogo = B.PrecioOfertaSet,
	Set_PrecioOfertaTotalRevista = 0,
	Set_DescuentoTotalCatalogo = B.DescuentoSet,
	Set_DescuentoTotalRevista = 0,
	Set_FlagFragancias = CASE WHEN B.FlagFragancias > 0 THEN B.FlagFragancias ELSE Set_FlagFragancias END,
	Set_FlagCuidadoPersonal = CASE WHEN B.FlagCuidadoPersonal > 0 THEN B.FlagCuidadoPersonal ELSE Set_FlagCuidadoPersonal END,
	Set_FlagTratamientoCorporal = CASE WHEN B.FlagTratamientoCorporal > 0 THEN B.FlagTratamientoCorporal ELSE Set_FlagTratamientoCorporal END,
	Set_FlagTratamientoFacial = CASE WHEN B.FlagTratamientoFacial > 0 THEN B.FlagTratamientoFacial ELSE Set_FlagTratamientoFacial END,
	Set_FlagMaquillaje = CASE WHEN B.FlagMaquillaje > 0 THEN B.FlagMaquillaje ELSE Set_FlagMaquillaje END,
	Set_FlagExtensionLinea = 0,
	Set_IncluyeBolsa = CASE WHEN B.FlagBolsa > 0 THEN B.FlagBolsa ELSE Set_IncluyeBolsa END,
	Set_ComponenteTop = CASE WHEN B.FlagTop > 0 THEN B.FlagTop ELSE Set_ComponenteTop END
FROM #BASE_SETS A INNER JOIN #TMP_SETS B ON A.AnioCampana = B.AnioCampana AND A.CodCUC = B.CodCUC
WHERE B.DescripcionCatalogo NOT IN ('24 - REVISTA BELCORP')

IF (SELECT SUM(FlagSet) FROM #BASE_SETS) = 0 AND (SELECT COUNT(Niveles_FactorRango) FROM #BASE_NIVELES WHERE ISNULL(Niveles_FactorRango,'') <> '') = 0
BEGIN
		SELECT * FROM #BASE_PROMOCIONES ORDER BY ANIOCAMPANA, CODCUC
END
ELSE IF (SELECT SUM(FlagSet) FROM #BASE_SETS) = 0 AND (SELECT COUNT(Niveles_FactorRango) FROM #BASE_NIVELES WHERE ISNULL(Niveles_FactorRango,'') <> '') > 0
BEGIN
		SELECT * FROM #BASE_NIVELES ORDER BY ANIOCAMPANA, CODCUC
END
ELSE SELECT * FROM #BASE_SETS ORDER BY ANIOCAMPANA, CODCUC