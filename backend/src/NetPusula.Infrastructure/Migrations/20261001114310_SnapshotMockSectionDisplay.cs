using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace NetPusula.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class SnapshotMockSectionDisplay : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "GroupCodeSnapshot",
                table: "MockExamResults",
                type: "character varying(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "GroupNameSnapshot",
                table: "MockExamResults",
                type: "character varying(200)",
                maxLength: 200,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SectionCodeSnapshot",
                table: "MockExamResults",
                type: "character varying(64)",
                maxLength: 64,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "SectionNameSnapshot",
                table: "MockExamResults",
                type: "character varying(200)",
                maxLength: 200,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<int>(
                name: "SortOrderSnapshot",
                table: "MockExamResults",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            // Existing rows retain numeric snapshots; display metadata can only be recovered
            // from the referenced catalogue as it exists at migration time.
            migrationBuilder.Sql("""
                UPDATE "MockExamResults" SET
                  "SectionCodeSnapshot" = (SELECT "Code" FROM "ExamSections" WHERE "Id" = "MockExamResults"."ExamSectionId"),
                  "SectionNameSnapshot" = (SELECT "Name" FROM "ExamSections" WHERE "Id" = "MockExamResults"."ExamSectionId"),
                  "GroupCodeSnapshot" = (SELECT "GroupCode" FROM "ExamSections" WHERE "Id" = "MockExamResults"."ExamSectionId"),
                  "GroupNameSnapshot" = (SELECT "GroupName" FROM "ExamSections" WHERE "Id" = "MockExamResults"."ExamSectionId"),
                  "SortOrderSnapshot" = (SELECT "SortOrder" FROM "ExamSections" WHERE "Id" = "MockExamResults"."ExamSectionId");
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "GroupCodeSnapshot",
                table: "MockExamResults");

            migrationBuilder.DropColumn(
                name: "GroupNameSnapshot",
                table: "MockExamResults");

            migrationBuilder.DropColumn(
                name: "SectionCodeSnapshot",
                table: "MockExamResults");

            migrationBuilder.DropColumn(
                name: "SectionNameSnapshot",
                table: "MockExamResults");

            migrationBuilder.DropColumn(
                name: "SortOrderSnapshot",
                table: "MockExamResults");
        }
    }
}
