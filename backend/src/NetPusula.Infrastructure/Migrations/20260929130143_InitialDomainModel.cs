using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace NetPusula.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class InitialDomainModel : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Exams",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Code = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Description = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    SortOrder = table.Column<int>(type: "integer", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Exams", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "Users",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Email = table.Column<string>(type: "character varying(320)", maxLength: 320, nullable: false),
                    NormalizedEmail = table.Column<string>(type: "character varying(320)", maxLength: 320, nullable: false),
                    DisplayName = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    PasswordHash = table.Column<string>(type: "character varying(1024)", maxLength: 1024, nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Users", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "ExamSections",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ExamId = table.Column<Guid>(type: "uuid", nullable: false),
                    Code = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    GroupCode = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    GroupName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    QuestionCount = table.Column<int>(type: "integer", nullable: false),
                    PenaltyDivisor = table.Column<decimal>(type: "numeric(10,4)", precision: 10, scale: 4, nullable: false),
                    SortOrder = table.Column<int>(type: "integer", nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ExamSections", x => x.Id);
                    table.UniqueConstraint("AK_ExamSections_Id_ExamId", x => new { x.Id, x.ExamId });
                    table.CheckConstraint("CK_ExamSections_Group", "(\"GroupCode\" IS NULL AND \"GroupName\" IS NULL) OR (\"GroupCode\" IS NOT NULL AND \"GroupName\" IS NOT NULL)");
                    table.CheckConstraint("CK_ExamSections_PenaltyDivisor", "\"PenaltyDivisor\" > 0");
                    table.CheckConstraint("CK_ExamSections_QuestionCount", "\"QuestionCount\" > 0");
                    table.ForeignKey(
                        name: "FK_ExamSections_Exams_ExamId",
                        column: x => x.ExamId,
                        principalTable: "Exams",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "UserExams",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    ExamId = table.Column<Guid>(type: "uuid", nullable: false),
                    TargetNet = table.Column<decimal>(type: "numeric(12,4)", precision: 12, scale: 4, nullable: false),
                    ExamDate = table.Column<DateOnly>(type: "date", nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserExams", x => x.Id);
                    table.UniqueConstraint("AK_UserExams_Id_ExamId", x => new { x.Id, x.ExamId });
                    table.CheckConstraint("CK_UserExams_TargetNet", "\"TargetNet\" >= 0");
                    table.ForeignKey(
                        name: "FK_UserExams_Exams_ExamId",
                        column: x => x.ExamId,
                        principalTable: "Exams",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_UserExams_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "MockExams",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserExamId = table.Column<Guid>(type: "uuid", nullable: false),
                    ExamId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    TakenAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    Notes = table.Column<string>(type: "character varying(4000)", maxLength: 4000, nullable: true),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MockExams", x => x.Id);
                    table.UniqueConstraint("AK_MockExams_Id_ExamId", x => new { x.Id, x.ExamId });
                    table.ForeignKey(
                        name: "FK_MockExams_UserExams_UserExamId_ExamId",
                        columns: x => new { x.UserExamId, x.ExamId },
                        principalTable: "UserExams",
                        principalColumns: new[] { "Id", "ExamId" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "MockExamResults",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    MockExamId = table.Column<Guid>(type: "uuid", nullable: false),
                    ExamSectionId = table.Column<Guid>(type: "uuid", nullable: false),
                    ExamId = table.Column<Guid>(type: "uuid", nullable: false),
                    CorrectCount = table.Column<int>(type: "integer", nullable: false),
                    WrongCount = table.Column<int>(type: "integer", nullable: false),
                    BlankCount = table.Column<int>(type: "integer", nullable: false),
                    QuestionCountSnapshot = table.Column<int>(type: "integer", nullable: false),
                    PenaltyDivisorSnapshot = table.Column<decimal>(type: "numeric(10,4)", precision: 10, scale: 4, nullable: false),
                    CreatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MockExamResults", x => x.Id);
                    table.CheckConstraint("CK_MockExamResults_Counts", "\"CorrectCount\" >= 0 AND \"WrongCount\" >= 0 AND \"BlankCount\" >= 0");
                    table.CheckConstraint("CK_MockExamResults_PenaltyDivisor", "\"PenaltyDivisorSnapshot\" > 0");
                    table.CheckConstraint("CK_MockExamResults_QuestionCount", "\"QuestionCountSnapshot\" > 0 AND CAST(\"CorrectCount\" AS bigint) + \"WrongCount\" + \"BlankCount\" <= \"QuestionCountSnapshot\"");
                    table.ForeignKey(
                        name: "FK_MockExamResults_ExamSections_ExamSectionId_ExamId",
                        columns: x => new { x.ExamSectionId, x.ExamId },
                        principalTable: "ExamSections",
                        principalColumns: new[] { "Id", "ExamId" },
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_MockExamResults_MockExams_MockExamId_ExamId",
                        columns: x => new { x.MockExamId, x.ExamId },
                        principalTable: "MockExams",
                        principalColumns: new[] { "Id", "ExamId" },
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.InsertData(
                table: "Exams",
                columns: new[] { "Id", "Code", "CreatedAtUtc", "Description", "IsActive", "Name", "SortOrder", "UpdatedAtUtc" },
                values: new object[,]
                {
                    { new Guid("00000000-0000-0000-0000-000000000001"), "YKS", new DateTime(2026, 9, 29, 0, 0, 0, 0, DateTimeKind.Utc), null, true, "Yükseköğretim Kurumları Sınavı", 10, null },
                    { new Guid("00000000-0000-0000-0000-000000000002"), "KPSS", new DateTime(2026, 9, 29, 0, 0, 0, 0, DateTimeKind.Utc), null, true, "Kamu Personel Seçme Sınavı", 20, null },
                    { new Guid("00000000-0000-0000-0000-000000000003"), "ALES", new DateTime(2026, 9, 29, 0, 0, 0, 0, DateTimeKind.Utc), null, true, "Akademik Personel ve Lisansüstü Eğitimi Giriş Sınavı", 30, null },
                    { new Guid("00000000-0000-0000-0000-000000000004"), "DGS", new DateTime(2026, 9, 29, 0, 0, 0, 0, DateTimeKind.Utc), null, true, "Dikey Geçiş Sınavı", 40, null },
                    { new Guid("00000000-0000-0000-0000-000000000005"), "MSU", new DateTime(2026, 9, 29, 0, 0, 0, 0, DateTimeKind.Utc), null, true, "Millî Savunma Üniversitesi Askerî Öğrenci Aday Belirleme Sınavı", 50, null },
                    { new Guid("00000000-0000-0000-0000-000000000006"), "YDS", new DateTime(2026, 9, 29, 0, 0, 0, 0, DateTimeKind.Utc), null, true, "Yabancı Dil Bilgisi Seviye Tespit Sınavı", 60, null }
                });

            migrationBuilder.InsertData(
                table: "ExamSections",
                columns: new[] { "Id", "Code", "CreatedAtUtc", "ExamId", "GroupCode", "GroupName", "IsActive", "Name", "PenaltyDivisor", "QuestionCount", "SortOrder", "UpdatedAtUtc" },
                values: new object[,]
                {
                    { new Guid("00000000-0000-0000-0000-000000000301"), "SAYISAL", new DateTime(2026, 9, 29, 0, 0, 0, 0, DateTimeKind.Utc), new Guid("00000000-0000-0000-0000-000000000003"), null, null, true, "Sayısal", 4m, 50, 10, null },
                    { new Guid("00000000-0000-0000-0000-000000000302"), "SOZEL", new DateTime(2026, 9, 29, 0, 0, 0, 0, DateTimeKind.Utc), new Guid("00000000-0000-0000-0000-000000000003"), null, null, true, "Sözel", 4m, 50, 20, null }
                });

            migrationBuilder.CreateIndex(
                name: "IX_Exams_Code",
                table: "Exams",
                column: "Code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Exams_IsActive_SortOrder",
                table: "Exams",
                columns: new[] { "IsActive", "SortOrder" });

            migrationBuilder.CreateIndex(
                name: "IX_ExamSections_ExamId_Code",
                table: "ExamSections",
                columns: new[] { "ExamId", "Code" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_ExamSections_ExamId_IsActive_SortOrder",
                table: "ExamSections",
                columns: new[] { "ExamId", "IsActive", "SortOrder" });

            migrationBuilder.CreateIndex(
                name: "IX_MockExamResults_ExamSectionId_ExamId",
                table: "MockExamResults",
                columns: new[] { "ExamSectionId", "ExamId" });

            migrationBuilder.CreateIndex(
                name: "IX_MockExamResults_MockExamId_ExamId",
                table: "MockExamResults",
                columns: new[] { "MockExamId", "ExamId" });

            migrationBuilder.CreateIndex(
                name: "IX_MockExamResults_MockExamId_ExamSectionId",
                table: "MockExamResults",
                columns: new[] { "MockExamId", "ExamSectionId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_MockExams_UserExamId_ExamId",
                table: "MockExams",
                columns: new[] { "UserExamId", "ExamId" });

            migrationBuilder.CreateIndex(
                name: "IX_MockExams_UserExamId_TakenAtUtc",
                table: "MockExams",
                columns: new[] { "UserExamId", "TakenAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_UserExams_ExamId",
                table: "UserExams",
                column: "ExamId");

            migrationBuilder.CreateIndex(
                name: "IX_UserExams_UserId_IsActive",
                table: "UserExams",
                columns: new[] { "UserId", "IsActive" });

            migrationBuilder.CreateIndex(
                name: "IX_Users_NormalizedEmail",
                table: "Users",
                column: "NormalizedEmail",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "MockExamResults");

            migrationBuilder.DropTable(
                name: "ExamSections");

            migrationBuilder.DropTable(
                name: "MockExams");

            migrationBuilder.DropTable(
                name: "UserExams");

            migrationBuilder.DropTable(
                name: "Exams");

            migrationBuilder.DropTable(
                name: "Users");
        }
    }
}
