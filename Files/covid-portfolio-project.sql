
  --COVID-19 DATA ANALYSIS: Vaccination Impact on Mortality
 -- Author  : Julia Monson
 -- Course  : BAIS 4720 – Business Analytics | Eastern Illinois University
 -- Data    : Our World in Data – COVID Deaths & Vaccinations Datasets
  --Tool    : Microsoft SQL Server

  --Research Questions:
  --  1. Did COVID-19 vaccination rollout correlate with reductions in mortality?
  --  2. Which countries were hit hardest, and when did vaccines arrive?
   -- 3. What does the global and continental picture look like over time?

--Data Exploration
-- 1. Preview the Deaths dataset
SELECT TOP 100
    location,
    continent,
    date,
    total_cases,
    new_cases,
    total_deaths,
    new_deaths,
    population
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
ORDER BY location, date;

-- 2. Preview the Vaccinations dataset
SELECT TOP 100
    location,
    date,
    new_vaccinations,
    people_vaccinated,
    people_fully_vaccinated
FROM PortfolioProject..CovidVaccinations
WHERE continent IS NOT NULL
ORDER BY location, date;

--3. Check date range of the dataset
SELECT
    MIN(date) AS EarliestDate,
    MAX(date) AS LatestDate,
    COUNT(DISTINCT location) AS TotalCountries
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL;


-- DEATH RATE ANALYSIS
-- Research Question 2: Which countries were hit hardest?


-- 1. Case Fatality Rate by country over time
--     (likelihood of dying if you tested positive for COVID)
SELECT
    location,
    date,
    total_cases,
    total_deaths,
    ROUND((CAST(total_deaths AS FLOAT) / NULLIF(total_cases, 0)) * 100, 4) AS CaseFatalityRate_Pct
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
ORDER BY location, date;

-- 2. Case Fatality Rate focused on the 5 key countries in this study
--     (US, UK, India, Mexico, China -- chosen for data reliability)
SELECT
    location,
    date,
    total_cases,
    total_deaths,
    ROUND((CAST(total_deaths AS FLOAT) / NULLIF(total_cases, 0)) * 100, 4) AS CaseFatalityRate_Pct
FROM PortfolioProject..CovidDeaths
WHERE location IN ('United States', 'United Kingdom', 'India', 'Mexico', 'China')
ORDER BY location, date;

-- 3. Percentage of population that contracted COVID by country
SELECT
    location,
    population,
    MAX(total_cases) AS PeakTotalCases,
    ROUND(MAX(CAST(total_cases AS FLOAT) / NULLIF(population, 0)) * 100, 2) AS PctPopulationInfected
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY PctPopulationInfected DESC;

-- 4. Countries ranked by total death count (absolute numbers)
SELECT
    location,
    population,
    MAX(CAST(total_deaths AS BIGINT)) AS TotalDeathCount,
    RANK() OVER (ORDER BY MAX(CAST(total_deaths AS BIGINT)) DESC) AS DeathRank
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY TotalDeathCount DESC;

-- 5. Countries ranked by death count per 100,000 population
--     (fairer comparison across differently sized countries)
SELECT
    location,
    population,
    MAX(CAST(total_deaths AS BIGINT)) AS TotalDeathCount,
    ROUND(
        MAX(CAST(total_deaths AS FLOAT)) / NULLIF(population, 0) * 100000,
        2
    ) AS DeathsPer100k,
    RANK() OVER (
        ORDER BY MAX(CAST(total_deaths AS FLOAT)) / NULLIF(population, 0) DESC
    ) AS MortalityRank
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY DeathsPer100k DESC;

-- 6. Death counts broken down by continent
SELECT
    continent,
    MAX(CAST(total_deaths AS BIGINT)) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER BY TotalDeathCount DESC;



-- GLOBAL NUMBERS



-- 1. Overall global totals (all time)
SELECT
    SUM(CAST(new_cases AS BIGINT))                              AS GlobalTotalCases,
    SUM(CAST(new_deaths AS BIGINT))                            AS GlobalTotalDeaths,
    ROUND(
        SUM(CAST(new_deaths AS FLOAT)) / NULLIF(SUM(CAST(new_cases AS FLOAT)), 0) * 100,
        4
    )                                                           AS GlobalCaseFatalityRate_Pct
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL;

-- 2. Global numbers broken down by date
--     (used for time-series trend lines in Tableau)
SELECT
    date,
    SUM(CAST(new_cases AS BIGINT))  AS DailyNewCases,
    SUM(CAST(new_deaths AS BIGINT)) AS DailyNewDeaths,
    ROUND(
        SUM(CAST(new_deaths AS FLOAT)) / NULLIF(SUM(CAST(new_cases AS FLOAT)), 0) * 100,
        4
    )                               AS DailyCaseFatalityRate_Pct
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY date
ORDER BY date;



--VACCINATION ROLLOUT ANALYSIS
-- Research Question 1: Did vaccination correlate with reduced mortality?


-- 1. Rolling vaccination count per country over time (CTE method)
--     Shows the cumulative vaccine rollout trajectory for each country
WITH RollingVaccinations AS
(
    SELECT
        dea.continent,
        dea.location,
        dea.date,
        dea.population,
        vac.new_vaccinations,
        SUM(CAST(vac.new_vaccinations AS BIGINT))
            OVER (PARTITION BY dea.location ORDER BY dea.date)
            AS RollingPeopleVaccinated
    FROM PortfolioProject..CovidDeaths dea
    JOIN PortfolioProject..CovidVaccinations vac
        ON dea.location = vac.location
        AND dea.date    = vac.date
    WHERE dea.continent IS NOT NULL
)
SELECT
    continent,
    location,
    date,
    population,
    new_vaccinations,
    RollingPeopleVaccinated,
    ROUND((CAST(RollingPeopleVaccinated AS FLOAT) / NULLIF(population, 0)) * 100, 4)
        AS PctPopulationVaccinated
FROM RollingVaccinations
ORDER BY location, date;

-- 2. Vaccination milestones: when did each country first reach 10%, 25%, and 50% vaccinated?
--     Useful for comparing rollout speed across countries
WITH VaccinationProgress AS
(
    SELECT
        dea.location,
        dea.date,
        dea.population,
        SUM(CAST(vac.new_vaccinations AS BIGINT))
            OVER (PARTITION BY dea.location ORDER BY dea.date)
            AS RollingVaccinated
    FROM PortfolioProject..CovidDeaths dea
    JOIN PortfolioProject..CovidVaccinations vac
        ON dea.location = vac.location
        AND dea.date    = vac.date
    WHERE dea.continent IS NOT NULL
),
MilestoneDates AS
(
    SELECT
        location,
        date,
        population,
        RollingVaccinated,
        ROUND(CAST(RollingVaccinated AS FLOAT) / NULLIF(population, 0) * 100, 2) AS PctVaccinated,
        ROW_NUMBER() OVER (PARTITION BY location ORDER BY date) AS RowNum
    FROM VaccinationProgress
    WHERE CAST(RollingVaccinated AS FLOAT) / NULLIF(population, 0) >= 0.10
)
SELECT location, MIN(date) AS DateReached10PctVaccinated
FROM MilestoneDates
GROUP BY location
ORDER BY DateReached10PctVaccinated;

-- 3. Peak vaccination rate vs. peak death rate per country
--     Core comparison: countries with faster vaccine rollout vs. mortality outcomes
SELECT
    dea.location,
    dea.population,
    MAX(CAST(dea.total_deaths AS BIGINT))                              AS PeakTotalDeaths,
    ROUND(
        MAX(CAST(dea.total_deaths AS FLOAT)) / NULLIF(dea.population, 0) * 100000,
        2
    )                                                                   AS DeathsPer100k,
    MAX(CAST(vac.people_fully_vaccinated AS BIGINT))                   AS PeakFullyVaccinated,
    ROUND(
        MAX(CAST(vac.people_fully_vaccinated AS FLOAT)) / NULLIF(dea.population, 0) * 100,
        2
    )                                                                   AS PeakPctFullyVaccinated
FROM PortfolioProject..CovidDeaths dea
JOIN PortfolioProject..CovidVaccinations vac
    ON dea.location = vac.location
    AND dea.date    = vac.date
WHERE dea.continent IS NOT NULL
GROUP BY dea.location, dea.population
ORDER BY DeathsPer100k DESC;



-- ADVANCED TREND ANALYSIS
-- Month-over-month changes using window functions (LAG)
-- Shows whether death rates were rising or falling over time


-- 1. Monthly death trend with month-over-month change
--     LAG() compares each month to the previous month
WITH MonthlyDeaths AS
(
    SELECT
        location,
        YEAR(date)  AS YearNum,
        MONTH(date) AS MonthNum,
        SUM(CAST(new_deaths AS BIGINT)) AS MonthlyDeaths,
        SUM(CAST(new_cases AS BIGINT))  AS MonthlyCases
    FROM PortfolioProject..CovidDeaths
    WHERE continent IS NOT NULL
    GROUP BY location, YEAR(date), MONTH(date)
)
SELECT
    location,
    YearNum,
    MonthNum,
    MonthlyDeaths,
    MonthlyCases,
    LAG(MonthlyDeaths) OVER (PARTITION BY location ORDER BY YearNum, MonthNum)
        AS PrevMonthDeaths,
    MonthlyDeaths -
        LAG(MonthlyDeaths) OVER (PARTITION BY location ORDER BY YearNum, MonthNum)
        AS MonthOverMonthChange,
    ROUND(
        CAST(MonthlyDeaths AS FLOAT) / NULLIF(MonthlyCases, 0) * 100,
        4
    ) AS MonthlyCaseFatalityRate_Pct
FROM MonthlyDeaths
ORDER BY location, YearNum, MonthNum;

-- 2. Pre vs. Post vaccination death rate comparison for 5 focus countries
--     Vaccination rollout began December 2020 -- split the data there
--     This directly answers Research Question 1
SELECT
    location,
    CASE
        WHEN date < '2021-01-01' THEN 'Pre-Vaccination Era (2020)'
        WHEN date BETWEEN '2021-01-01' AND '2021-12-31' THEN 'Early Vaccination Era (2021)'
        ELSE 'Expanded Vaccination Era (2022+)'
    END AS VaccinationEra,
    SUM(CAST(new_cases AS BIGINT))  AS TotalCases,
    SUM(CAST(new_deaths AS BIGINT)) AS TotalDeaths,
    ROUND(
        SUM(CAST(new_deaths AS FLOAT)) / NULLIF(SUM(CAST(new_cases AS FLOAT)), 0) * 100,
        4
    ) AS CaseFatalityRate_Pct
FROM PortfolioProject..CovidDeaths
WHERE location IN ('United States', 'United Kingdom', 'India', 'Mexico', 'China')
    AND continent IS NOT NULL
GROUP BY
    location,
    CASE
        WHEN date < '2021-01-01' THEN 'Pre-Vaccination Era (2020)'
        WHEN date BETWEEN '2021-01-01' AND '2021-12-31' THEN 'Early Vaccination Era (2021)'
        ELSE 'Expanded Vaccination Era (2022+)'
    END
ORDER BY location, VaccinationEra;

-- 3. 7-day rolling average of new deaths per country
--     Smooths out daily reporting spikes for cleaner trend visualization
SELECT
    location,
    date,
    new_deaths,
    AVG(CAST(new_deaths AS FLOAT))
        OVER (
            PARTITION BY location
            ORDER BY date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS SevenDayAvgDeaths
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
    AND location IN ('United States', 'United Kingdom', 'India', 'Mexico', 'China')
ORDER BY location, date;


-- TEMP TABLE
-- Stores vaccination percentage data for reuse across multiple queries


DROP TABLE IF EXISTS #VaccinationSummary;

CREATE TABLE #VaccinationSummary
(
    Continent               NVARCHAR(255),
    Location                NVARCHAR(255),
    Date                    DATETIME,
    Population              NUMERIC,
    New_Vaccinations        NUMERIC,
    RollingPeopleVaccinated NUMERIC
);

INSERT INTO #VaccinationSummary
SELECT
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    vac.new_vaccinations,
    SUM(CAST(vac.new_vaccinations AS BIGINT))
        OVER (PARTITION BY dea.location ORDER BY dea.date)
        AS RollingPeopleVaccinated
FROM PortfolioProject..CovidDeaths dea
JOIN PortfolioProject..CovidVaccinations vac
    ON dea.location = vac.location
    AND dea.date    = vac.date
WHERE dea.continent IS NOT NULL;

-- Query the temp table
SELECT
    *,
    ROUND(
        (RollingPeopleVaccinated / NULLIF(Population, 0)) * 100,
        4
    ) AS PctPopulationVaccinated
FROM #VaccinationSummary
ORDER BY Location, Date;

--  VIEWS FOR TABLEAU DASHBOARDS


-- View 1: Global summary KPIs (feeds the top summary tile)
CREATE OR ALTER VIEW vw_GlobalSummary AS
SELECT
    SUM(CAST(new_cases AS BIGINT))  AS GlobalTotalCases,
    SUM(CAST(new_deaths AS BIGINT)) AS GlobalTotalDeaths,
    ROUND(
        SUM(CAST(new_deaths AS FLOAT)) / NULLIF(SUM(CAST(new_cases AS FLOAT)), 0) * 100,
        4
    )                               AS GlobalCaseFatalityRate_Pct
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL;
GO

-- View 2: Percent population infected per country (feeds the world map)
CREATE OR ALTER VIEW vw_InfectionRateByCountry AS
SELECT
    location,
    population,
    MAX(total_cases)                                                         AS HighestCaseCount,
    ROUND(
        MAX(CAST(total_cases AS FLOAT)) / NULLIF(population, 0) * 100,
        4
    )                                                                        AS PctPopulationInfected
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY location, population;
GO

-- View 3: Death count by continent (feeds the bar chart)
CREATE OR ALTER VIEW vw_DeathsByContinent AS
SELECT
    continent,
    MAX(CAST(total_deaths AS BIGINT)) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
GROUP BY continent;
GO

-- View 4: Rolling vaccination progress (feeds the vaccination timeline chart)
CREATE OR ALTER VIEW vw_RollingVaccinationProgress AS
SELECT
    dea.continent,
    dea.location,
    dea.date,
    dea.population,
    vac.new_vaccinations,
    SUM(CAST(vac.new_vaccinations AS BIGINT))
        OVER (PARTITION BY dea.location ORDER BY dea.date)
        AS RollingPeopleVaccinated
FROM PortfolioProject..CovidDeaths dea
JOIN PortfolioProject..CovidVaccinations vac
    ON dea.location = vac.location
    AND dea.date    = vac.date
WHERE dea.continent IS NOT NULL;
GO

-- View 5: Pre vs. Post vaccination death rates for 5 focus countries
--         (feeds the before/after comparison chart)
CREATE OR ALTER VIEW vw_PrePostVaccinationDeathRate AS
SELECT
    location,
    CASE
        WHEN date < '2021-01-01' THEN 'Pre-Vaccination Era (2020)'
        WHEN date BETWEEN '2021-01-01' AND '2021-12-31' THEN 'Early Vaccination Era (2021)'
        ELSE 'Expanded Vaccination Era (2022+)'
    END AS VaccinationEra,
    SUM(CAST(new_cases AS BIGINT))  AS TotalCases,
    SUM(CAST(new_deaths AS BIGINT)) AS TotalDeaths,
    ROUND(
        SUM(CAST(new_deaths AS FLOAT)) / NULLIF(SUM(CAST(new_cases AS FLOAT)), 0) * 100,
        4
    )                               AS CaseFatalityRate_Pct
FROM PortfolioProject..CovidDeaths
WHERE location IN ('United States', 'United Kingdom', 'India', 'Mexico', 'China')
    AND continent IS NOT NULL
GROUP BY
    location,
    CASE
        WHEN date < '2021-01-01' THEN 'Pre-Vaccination Era (2020)'
        WHEN date BETWEEN '2021-01-01' AND '2021-12-31' THEN 'Early Vaccination Era (2021)'
        ELSE 'Expanded Vaccination Era (2022+)'
    END;
GO

-- View 6: 7-day rolling average deaths (feeds smoothed trend line)
CREATE OR ALTER VIEW vw_SevenDayDeathAverage AS
SELECT
    location,
    date,
    new_deaths,
    AVG(CAST(new_deaths AS FLOAT))
        OVER (
            PARTITION BY location
            ORDER BY date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) AS SevenDayAvgDeaths
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
    AND location IN ('United States', 'United Kingdom', 'India', 'Mexico', 'China');
GO

--verifying veiws
SELECT * FROM vw_GlobalSummary;
SELECT * FROM vw_InfectionRateByCountry    ORDER BY PctPopulationInfected DESC;
SELECT * FROM vw_DeathsByContinent         ORDER BY TotalDeathCount DESC;
SELECT * FROM vw_RollingVaccinationProgress ORDER BY location, date;
SELECT * FROM vw_PrePostVaccinationDeathRate ORDER BY location, VaccinationEra;
SELECT * FROM vw_SevenDayDeathAverage       ORDER BY location, date;
