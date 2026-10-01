using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace NetPusula.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class EnforceSingleActiveUserExam : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "HasCompleteSectionConfiguration",
                table: "Exams",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.UpdateData(
                table: "Exams",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000001"),
                column: "HasCompleteSectionConfiguration",
                value: false);

            migrationBuilder.UpdateData(
                table: "Exams",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000002"),
                column: "HasCompleteSectionConfiguration",
                value: false);

            migrationBuilder.UpdateData(
                table: "Exams",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000003"),
                column: "HasCompleteSectionConfiguration",
                value: true);

            migrationBuilder.UpdateData(
                table: "Exams",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000004"),
                column: "HasCompleteSectionConfiguration",
                value: false);

            migrationBuilder.UpdateData(
                table: "Exams",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000005"),
                column: "HasCompleteSectionConfiguration",
                value: false);

            migrationBuilder.UpdateData(
                table: "Exams",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000006"),
                column: "HasCompleteSectionConfiguration",
                value: false);

            // Retain every row and its history; deterministically keep the newest active preparation.
            migrationBuilder.Sql("""
                WITH ranked AS (
                    SELECT "Id", ROW_NUMBER() OVER (PARTITION BY "UserId" ORDER BY "CreatedAtUtc" DESC, "Id" DESC) AS position
                    FROM "UserExams" WHERE "IsActive" = TRUE
                )
                UPDATE "UserExams" SET "IsActive" = FALSE, "UpdatedAtUtc" = CURRENT_TIMESTAMP
                WHERE "Id" IN (SELECT "Id" FROM ranked WHERE position > 1);
                """);
            migrationBuilder.CreateIndex(
                name: "UX_UserExams_OneActivePerUser",
                table: "UserExams",
                column: "UserId",
                unique: true,
                filter: "\"IsActive\" = TRUE");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "UX_UserExams_OneActivePerUser",
                table: "UserExams");

            migrationBuilder.DropColumn(
                name: "HasCompleteSectionConfiguration",
                table: "Exams");
        }
    }
}

