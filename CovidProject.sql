-- ovrview the data Death 
USE ProjectCovid;

SELECT * FROM Death
ORDER BY location, date;

-- Which continents in tha date?
SELECT DISTINCT continent FROM Death;

-- Data contain NULL values, check data
SELECT * FROM Death
WHERE continent IS NULL;

-- Which location in the data?
SELECT DISTINCT location FROM Death
WHERE continent IS NOT NULL
ORDER BY location;


-- SELECT THE CONTINENT WITH SUM DEATH
SELECT *, ROUND((total_deaths / total_cases) * 100, 2) AS die_probability FROM 
	(SELECT continent, MAX(CONVERT(int, Death.total_deaths)) as total_deaths, SUM(new_cases) as total_cases FROM Death
	WHERE continent IS NOT null
	GROUP BY continent) AS calculate
ORDER BY continent, total_cases;



-- GET PERCENTAGE OF THE POPULATION GOT ILL AS A RESULT OF COVID19
SELECT *, ROUND((total_cases / population) * 100, 2) as case_percente FROM 
	(SELECT location, COALESCE(SUM(new_cases), 0) as total_cases, AVG(population) as population FROM Death
	WHERE continent IS NOT NULL
	GROUP BY location) as info
ORDER BY case_percente DESC;


-- GET PERCENTAGE OF THE POPULATION DIED AS A RESULT OF COVID19
SELECT *, ROUND((total_deaths / population) * 100, 2) as death_percente FROM 
	(SELECT location, COALESCE(MAX(CONVERT(int, total_deaths)), 0) as total_deaths, AVG(population) as population FROM Death
	WHERE continent IS NOT NULL
	GROUP BY location) as info
ORDER BY death_percente DESC, location;

-- GET location, PERCENT DEATH FROM TOTAL CASES WITH COVID19
SELECT * FROM (
	SELECT location, 
		SUM(new_cases) as total_cases, 
		MAX(CONVERT(int, Death.total_deaths)) as total_deaths, ROUND((MAX(CONVERT(int, Death.total_deaths)) / SUM(new_cases)) * 100, 2) as death_percent  
		FROM Death
	WHERE continent IS NOT NULL 
	GROUP BY location) AS loc
WHERE total_cases IS NOT NULL
	AND total_deaths IS NOT NULL
ORDER BY total_deaths DESC, death_percent DESC, location;


-- GET continent, PERCENT DEATH PER TOTAL CASES WITH COVID19
SELECT * FROM (
	SELECT continent, 
		SUM(new_cases) as total_cases, 
		MAX(CONVERT(int, Death.total_deaths)) as total_deaths, ROUND((MAX(CONVERT(int, Death.total_deaths)) / SUM(new_cases)) * 100, 2) as death_percent  
		FROM Death
	WHERE continent IS NOT NULL 
	GROUP BY continent) AS loc
WHERE total_cases IS NOT NULL
	AND total_deaths IS NOT NULL
ORDER BY total_deaths DESC, death_percent DESC, continent;


-- GLOBAL INFO BY DATE 
SELECT *, 
	CASE 
	WHEN TotalCase = 0 THEN 0
	ELSE (ROUND((TotalDeath/ NULLIF(TotalCase, 0)) * 100, 2)) 
	END AS DeathPercent FROM
		(SELECT date, COALESCE(SUM(new_cases), 0) AS TotalCase, 
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
		(SELECT COALESCE(SUM(new_cases), 0) AS TotalCase, 
			COALESCE(SUM(new_deaths), 0) AS TotalDeath
		FROM Death
		WHERE continent IS NOT NULL) AS sub;

-- SHOWING CONTINENTS WITH HIGHEST DEATH COUNT PER POPULATION


-- GET INFORMATION ABOUT GOT ILL BY MONTH/country
SELECT location, COALESCE(SUM(new_cases), 0) as new_cases_per_months, YEAR(date) AS year, MONTH(date) as month
FROM Death
WHERE continent IS NOT NULL
GROUP BY location, YEAR(date), MONTH(date)
ORDER BY location,  year, month;

-- GET INFORMATION ABOUT GOT ILL BY MONTH
SELECT MONTH(date) as month, COALESCE(SUM(new_cases), 0) as TotalCasesMonth
FROM Death
WHERE continent IS NOT NULL
GROUP BY MONTH(date)
ORDER BY TotalCasesMonth DESC, month;

-- GET ILL STATISTICS INFO ABOUT EACH COUNTRY
SELECT location, 
	ROUND(AVG(new_cases_per_months), 2) as avg_cases, 
	MIN(new_cases_per_months) as min_per_month, 
	MAX(new_cases_per_months) as max_per_month 
	FROM 
		(SELECT location, COALESCE(SUM(new_cases), 0) as new_cases_per_months, YEAR(date) AS year, MONTH(date) as month
			FROM Death
			WHERE continent IS NOT NULL
			GROUP BY location, YEAR(date), MONTH(date)) as sum_info
GROUP BY location
ORDER BY max_per_month DESC, location;

-- Get month where max cases in country
WITH total_cases AS (
    SELECT
        location, YEAR(date) AS year,
        MONTH(date) AS month, COALESCE(SUM(new_cases), 0) AS new_cases_per_month
    FROM
        Death
    WHERE
        continent IS NOT NULL
    GROUP BY location, YEAR(date), MONTH(date)
),
stats AS (
    SELECT
        location,
        ROUND(AVG(new_cases_per_month), 2) AS avg_cases,
        MIN(new_cases_per_month) AS min_per_month,
        MAX(new_cases_per_month) AS max_per_month,
        ROW_NUMBER() OVER (PARTITION BY location ORDER BY MAX(new_cases_per_month) DESC) AS rn
    FROM
        total_cases
    GROUP BY location
    HAVING AVG(new_cases_per_month) <> 0
)
SELECT
    total_cases.location,
    total_cases.month AS month,
	total_cases.year AS year,
    stats.max_per_month AS TotalCases
FROM
    total_cases
JOIN
    stats ON total_cases.location = stats.location AND total_cases.new_cases_per_month = stats.max_per_month
WHERE
    stats.rn = 1
ORDER BY
    TotalCases DESC, month, year, location;

-- Join tables
-- CREATE VIEW ShortInfo AS 
SELECT 
	dea.continent, dea.location, dea.population, dea.date, dea.new_cases, dea.new_deaths, COALESCE(vac.new_vaccinations, 0) AS NewVaccinations
FROM Death as dea
	JOIN Vaccinations as vac
ON dea.location = vac.location
AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;



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


SELECT location, COALESCE(ROUND(MAX(VacPercent), 2), 0) AS VacPercent FROM 
(SELECT
	*,
	ROUND((TotalVaccinations/population) * 100, 2) AS VacPercent  
FROM #VacShortResult) as sub
GROUP BY location
ORDER BY VacPercent DESC;

