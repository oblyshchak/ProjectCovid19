
USE ProjectCovid;

-- Ovrview the data Death 
SELECT 
	*
FROM Death
ORDER BY location, date;

-- Which continents in tha date?
SELECT 
	DISTINCT continent 
FROM Death;

-- Data contain NULL values, check data
SELECT 
	*
FROM Death
WHERE continent IS NULL;

-- Which location in the data?
SELECT 
	DISTINCT location 
FROM Death
WHERE continent IS NOT NULL
ORDER BY location;


-- How much death by Covid19? Get percent death vs total cases (Covid19)
SELECT *, 
	ROUND((TotalDeath / TotalCases)*100, 2) AS DeathPercent
	FROM (
	SELECT 
		SUM(new_cases) as TotalCases,
		SUM(new_deaths) as TotalDeath
		FROM Death) AS sub;


-- How much death by Covid19 in each continent? Get percent death vs total cases (Covid19)
SELECT 
	*,
	ROUND((TotalDeaths / TotalCases) * 100, 2) AS DiePercent
FROM 
	(SELECT 
		continent, 
		MAX(CONVERT(int, Death.total_deaths)) as TotalDeaths, 
		SUM(new_cases) as TotalCases
	FROM Death
	WHERE continent IS NOT null
	GROUP BY continent) AS calculate
ORDER BY continent, TotalCases;


-- Get percentage of the population got ill, died as a result Covid19 for each location(country)
SELECT 
	*, 
	ROUND((TotalCases / population) * 100, 2) as CasePercente,
	ROUND((TotalDeaths / population) * 100, 2) as DeathPercente
	FROM 
	(SELECT 
		location, 
		AVG(population) as population,
		COALESCE(SUM(new_cases), 0) as TotalCases, 
		COALESCE(MAX(CONVERT(int, total_deaths)), 0) as TotalDeaths
		FROM Death
	WHERE continent IS NOT NULL
	GROUP BY location) as info
ORDER BY CasePercente DESC, DeathPercente DESC, location;


-- Get info DeathPercent vs TotalCases
SELECT * FROM (
	SELECT 
		location, 
		SUM(new_cases) as TotalCases, 
		MAX(CONVERT(int, Death.total_deaths)) as TotalDeaths, 
		ROUND((MAX(CONVERT(int, Death.total_deaths)) / SUM(new_cases)) * 100, 2) as DeathPercent  
		FROM Death
	WHERE continent IS NOT NULL 
	GROUP BY location) AS loc
WHERE TotalCases IS NOT NULL
	AND TotalDeaths IS NOT NULL
ORDER BY TotalDeaths DESC, DeathPercent DESC, location;


-- Get rolling cases day by day for each country
SELECT 
	continent, 
	location, 
	population, 
	date, 
	new_cases,
	SUM(CAST(new_cases AS bigint)) OVER (PARTITION BY location ORDER BY date) as TotalCases
FROM Death 
ORDER BY location, date;

-- GLOBAL INFO BY DATE 
SELECT 
	*, 
	CASE 
	WHEN TotalCase = 0 THEN 0
	ELSE (ROUND((TotalDeath/ NULLIF(TotalCase, 0)) * 100, 2)) 
	END AS DeathPercent 
	FROM
		(SELECT 
			date, 
			COALESCE(SUM(new_cases), 0) AS TotalCase, 
			COALESCE(SUM(new_deaths), 0) AS TotalDeath
		FROM Death
		WHERE continent IS NOT NULL
		GROUP BY date) AS sub
ORDER BY date;

-- GLOBAL INFO 
SELECT *, 
	CASE 
	WHEN TotalCase = 0 THEN 0
	ELSE (ROUND((TotalDeath/ NULLIF(TotalCase, 0)) * 100, 2)) 
	END AS DeathPercent FROM
		(SELECT 
			COALESCE(SUM(new_cases), 0) AS TotalCase, 
			COALESCE(SUM(new_deaths), 0) AS TotalDeath
		FROM Death
		WHERE continent IS NOT NULL) AS sub;


-- Get information about got ill by month/year for countries
SELECT 
	location, 
	YEAR(date) AS year, 
	MONTH(date) as month,
	COALESCE(SUM(new_cases), 0) as NewCasesPerMonths
FROM Death
WHERE continent IS NOT NULL
GROUP BY location, YEAR(date), MONTH(date)
ORDER BY location,  year, month;

-- Get information sum got ill by month
SELECT 
	MONTH(date) as month, 
	COALESCE(SUM(new_cases), 0) as TotalCasesMonth
FROM Death
WHERE continent IS NOT NULL
GROUP BY MONTH(date)
ORDER BY month, TotalCasesMonth DESC;

-- Statistic info for each country
SELECT location, 
	ROUND(AVG(new_cases_per_months), 2) as AvgCases, 
	MIN(new_cases_per_months) as MinPerMonth, 
	MAX(new_cases_per_months) as MaxPerMonth 
	FROM 
		(SELECT 
			location, 
			COALESCE(SUM(new_cases), 0) as new_cases_per_months, 
			YEAR(date) AS year, 
			MONTH(date) as month
			FROM Death
			WHERE continent IS NOT NULL
			GROUP BY location, YEAR(date), MONTH(date)) as sum_info
GROUP BY location
ORDER BY MaxPerMonth DESC, location;

-- Get month with max cases in countries
WITH TotalCases AS (
    SELECT
        location, 
		YEAR(date) AS year,
        MONTH(date) AS month, 
		COALESCE(SUM(new_cases), 0) AS NewCasesPerMonths
    FROM
        Death
    WHERE
        continent IS NOT NULL
    GROUP BY location, YEAR(date), MONTH(date)
),
stats AS (
    SELECT
        location,
        ROUND(AVG(NewCasesPerMonths), 2) AS avg_cases,
        MIN(NewCasesPerMonths) AS min_per_month,
        MAX(NewCasesPerMonths) AS max_per_month,
        ROW_NUMBER() OVER (PARTITION BY location ORDER BY MAX(NewCasesPerMonths) DESC) AS rn
    FROM
        TotalCases
    GROUP BY location
    HAVING AVG(NewCasesPerMonths) <> 0
)
SELECT
    TotalCases.location,
    TotalCases.month AS month,
	TotalCases.year AS year,
    stats.max_per_month AS TotalCases
FROM TotalCases
JOIN
    stats ON TotalCases.location = stats.location 
	AND TotalCases.NewCasesPerMonths = stats.max_per_month
WHERE stats.rn = 1
ORDER BY location;


-- Join tables Death/Vaccination
-- CREATE VIEW ShortInfo AS 
SELECT 
	dea.continent, dea.location, dea.population, dea.date, dea.new_cases, dea.new_deaths, COALESCE(vac.new_vaccinations, 0) AS NewVaccinations
FROM Death as dea
	JOIN Vaccinations as vac
ON dea.location = vac.location
AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;


-- Calculate total vaccinations for each country, percent vaccinations day by day
WITH PopVac (continent, location, population, date, new_cases, new_deaths, NewVaccinations, TotalVaccinations) AS
(
SELECT 
	dea.continent, dea.location, 
	dea.population, dea.date, 
	dea.new_cases, dea.new_deaths, 
	COALESCE(vac.new_vaccinations, 0) AS NewVaccinations,
	SUM(CAST(vac.new_vaccinations AS bigint)) OVER (PARTITION BY dea.location ORDER BY dea.date) as TotalVaccinations
FROM Death as dea
	JOIN Vaccinations as vac
ON dea.location = vac.location
AND dea.date = vac.date
WHERE dea.continent IS NOT NULL)
SELECT 
	*, 
	ROUND((TotalVaccinations/population) * 100, 2) AS VacPercent 
FROM PopVac;

-- Create temp table for quick way getting the data
CREATE TABLE #VacShortResult
	(continent nvarchar(255),
	location nvarchar(255),
	population numeric,
	date Date,
	NewCases numeric,
	NewDeaths numeric,
	NewVaccinations numeric,
	TotalVaccinations numeric)

INSERT INTO #VacShortResult
SELECT 
	dea.continent, dea.location, 
	dea.population, dea.date, 
	dea.new_cases, dea.new_deaths, 
	COALESCE(vac.new_vaccinations, 0) AS NewVaccinations,
	SUM(CAST(vac.new_vaccinations AS bigint)) OVER (PARTITION BY dea.location ORDER BY dea.date) as TotalVaccinations
FROM Death as dea
	JOIN Vaccinations as vac
ON dea.location = vac.location
AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;

-- Get the total result vaccinations
SELECT 
	location, 
	COALESCE(ROUND(MAX(VacPercent), 2), 0) AS VacPercent 
	FROM 
	(SELECT
		*,
		ROUND((TotalVaccinations/population) * 100, 2) AS VacPercent  
	FROM #VacShortResult) as sub
GROUP BY location
ORDER BY location;


SELECT *, ROUND((TotalVaccinated/population) * 100, 2) AS PercentVac FROM
(SELECT 
	continent,
	SUM(DISTINCT population) as population,
	SUM(NewVaccinations) as TotalVaccinated 
FROM #VacShortResult
WHERE continent IS NOT NULL
GROUP BY continent) AS sub
ORDER BY continent;


-- Create view for bi 
CREATE VIEW PercentPopulationVaccinated AS
SELECT 
	dea.continent, dea.location, 
	dea.population, dea.date, 
	dea.new_cases, dea.new_deaths, 
	COALESCE(vac.new_vaccinations, 0) AS NewVaccinations,
	SUM(CAST(vac.new_vaccinations AS bigint)) OVER (PARTITION BY dea.location ORDER BY dea.date) as TotalVaccinations
FROM Death as dea
	JOIN Vaccinations as vac
ON dea.location = vac.location
AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;

SELECT * FROM PercentPopulationVaccinated;
