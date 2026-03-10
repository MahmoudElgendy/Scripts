# run this from the solution directory next to .sln file and src folder
dotnet new xunit -n School.Api.UnitTests -o tests/School.Api.UnitTests
dotnet new xunit -n School.Api.IntegrationTests -o tests/School.Api.IntegrationTests

dotnet sln add tests/School.Api.UnitTests/School.Api.UnitTests.csproj
dotnet sln add tests/School.Api.IntegrationTests/School.Api.IntegrationTests.csproj

dotnet add tests/School.Api.UnitTests/School.Api.UnitTests.csproj reference src/School.Api/School.Api.csproj
dotnet add tests/School.Api.IntegrationTests/School.Api.IntegrationTests.csproj reference src/School.Api/School.Api.csproj

dotnet add tests/School.Api.UnitTests package FluentAssertions
dotnet add tests/School.Api.UnitTests package Moq

dotnet add tests/School.Api.IntegrationTests package Microsoft.AspNetCore.Mvc.Testing
dotnet add tests/School.Api.IntegrationTests package FluentAssertions
dotnet add tests/School.Api.IntegrationTests package Microsoft.EntityFrameworkCore.InMemory

dotnet restore
dotnet test