/*
Covid 19 Data Exploration 

Skills used: Joins, CTE's, Temp Tables, Windows Functions, Aggregate Functions, Creating Views, Converting Data Types

*/

select *
From PortfolioProjects.dbo.CovidDeaths$
Order by 3,4

--Data selection
Select location, date, total_cases, new_cases, total_deaths, population
From PortfolioProjects.dbo.CovidDeaths$
Order by 1,2

--Total Cases vs Total Deaths
Select location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as DeathPercentage
From PortfolioProjects.dbo.CovidDeaths$
Order by 1,2

--Total Cases vs Total Deaths in Canada
Select location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as DeathPercentage
From PortfolioProjects.dbo.CovidDeaths$
Where location like '%canada%'
Order by 1,2

--Total Cases vs Population in a Canada
--Shows what percentage of population got covid
Select location, date, total_cases, population, (total_cases/population)*100 as InfectionPercentage
From PortfolioProjects.dbo.CovidDeaths$
Where location like '%canada%'
Order by 1,2

--Countries with the highest infection percentage
Select Location, population, MAX(total_cases) as HighestInfectionCount,  Max((total_cases/population))*100 as InfectionPercentage
From PortfolioProjects.dbo.CovidDeaths$
Group by Location, Population
order by InfectionPercentage desc

--Countries with highest death percentage
Select Location, population, MAX(cast(total_deaths as int)) as DeathCount,  Max((total_deaths/population))*100 as DeathPercentage
From PortfolioProjects.dbo.CovidDeaths$
where continent is not null
Group by Location, Population
order by DeathPercentage desc

--Global Numbers for New Cases and Deaths
Select SUM(new_cases) as new_total_cases, SUM(cast(new_deaths as int)) as new_total_deaths, SUM(cast(new_deaths as int))/SUM(New_Cases)*100 as DeathPercentage
From PortfolioProjects.dbo.CovidDeaths$
where continent is not null 
order by 1,2

-- Total Population vs Vaccinations
-- Shows Percentage of Population that has recieved at least one Covid Vaccine from the first day vaccination in Canada
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
, (SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date)/population)*100 as RollingPercentage
From PortfolioProjects.dbo.CovidDeaths$ dea
Join PortfolioProjects.dbo.CovidVaccinations$ vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null and vac.new_vaccinations is not null and dea.location like '%Canada%'
order by 2,3


-- Using CTE to perform Calculation on Partition By in previous query
With PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated)
as
(
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
From PortfolioProjects.dbo.CovidDeaths$ dea
Join PortfolioProjects.dbo.CovidVaccinations$ vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null and vac.new_vaccinations is not null and dea.location like '%Canada%'
order by 2,3
)
Select *, (RollingPeopleVaccinated/Population)*100 as RollingPercentage
From PopvsVac



-- Using Temp Table to perform Calculation on Partition By in previous query
DROP Table if exists #PercentPopulationVaccinated
Create Table #PercentPopulationVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_vaccinations numeric,
RollingPeopleVaccinated numeric
)

Insert into #PercentPopulationVaccinated
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
--, (RollingPeopleVaccinated/population)*100
From PortfolioProjects.dbo.CovidDeaths$ dea
Join PortfolioProjects.dbo.CovidVaccinations$ vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null and vac.new_vaccinations is not null and dea.location like '%Canada%'
order by 2,3

Select *, (RollingPeopleVaccinated/Population)*100 as RollingPercentage
From #PercentPopulationVaccinated


-- Creating View to store data for later visualizations using every country
Create View PercentPopulationVaccinated as
Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(CONVERT(int,vac.new_vaccinations)) OVER (Partition by dea.Location Order by dea.location, dea.Date) as RollingPeopleVaccinated
--, (RollingPeopleVaccinated/population)*100
From PortfolioProjects.dbo.CovidDeaths$ dea
Join PortfolioProjects.dbo.CovidVaccinations$ vac
	On dea.location = vac.location
	and dea.date = vac.date
where dea.continent is not null and vac.new_vaccinations is not null
