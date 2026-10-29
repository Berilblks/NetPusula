using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using NetPusula.Application.Auth;
using NetPusula.Domain;

namespace NetPusula.Infrastructure.Auth;

public sealed class AuthService(NetPusulaDbContext db, IPasswordHasher<User> passwordHasher,
    PasswordTimingHash timingHash, IAccessTokenIssuer tokenIssuer, IOptions<AuthSessionOptions> options,
    TimeProvider clock, ILogger<AuthService> logger, IGoogleTokenValidator google) : IAuthService
{
    public async Task<GoogleLinkOutcome> LinkGoogleAsync(Guid userId, GoogleLinkRequest request, CancellationToken cancellationToken)
    {
        var user = await db.Users.AsNoTracking().SingleOrDefaultAsync(x => x.Id == userId, cancellationToken);
        if (user is null) return new(Error: "session_expired");
        if (request.IdToken is null || request.IdToken.Length is < 1 or > 8192)
            return new(Error: "google_rejected");
        // Fresh proof of the local credential, not merely an old bearer session.
        if (user.PasswordHash is not null && (request.CurrentPassword is null ||
            request.CurrentPassword.Length is < 1 or > 128 ||
            passwordHasher.VerifyHashedPassword(user, user.PasswordHash, request.CurrentPassword) == PasswordVerificationResult.Failed))
            return new(Error: "reauth_required");
        var verified = await google.ValidateAsync(request.IdToken, cancellationToken);
        if (verified.Unavailable) return new(Error: "google_unavailable");
        if (verified.Identity is not { } identity) return new(Error: "google_rejected");
        if (user.GoogleSubject == identity.Subject) return new(await GetUserAsync(userId, cancellationToken));
        if (user.GoogleSubject is not null || user.PasswordHash is null) return new(Error: "google_link_conflict");
        if (await db.Users.AnyAsync(x => x.GoogleSubject == identity.Subject && x.Id != userId, cancellationToken))
            return new(Error: "google_link_conflict");
        try
        {
            // Atomic compare-and-set prevents concurrent requests replacing a linked subject.
            // The unique index also arbitrates a subject claimed by two different users.
            var changed = await db.Users.Where(x => x.Id == userId && x.GoogleSubject == null)
                .ExecuteUpdateAsync(setters => setters.SetProperty(x => x.GoogleSubject, identity.Subject), cancellationToken);
            if (changed == 0 && !await db.Users.AnyAsync(x => x.Id == userId && x.GoogleSubject == identity.Subject, cancellationToken))
                return new(Error: "google_link_conflict");
        }
        catch (Exception e) when (e is Npgsql.PostgresException { SqlState: "23505" })
        {
            return new(Error: "google_link_conflict");
        }
        return new(await GetUserAsync(userId, cancellationToken));
    }

    public async Task<AuthOutcome> GoogleAsync(GoogleLoginRequest request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.IdToken) || request.IdToken.Length > 8192)
            return new() { Failure = AuthFailure.GoogleRejected };
        var verified = await google.ValidateAsync(request.IdToken, cancellationToken);
        if (verified.Unavailable) return new() { Failure = AuthFailure.GoogleUnavailable };
        if (verified.Identity is not { } identity) return new() { Failure = AuthFailure.GoogleRejected };
        var user = await db.Users.SingleOrDefaultAsync(x => x.GoogleSubject == identity.Subject, cancellationToken);
        if (user is null)
        {
            var normalized = User.NormalizeEmail(identity.Email);
            if (await db.Users.AnyAsync(x => x.NormalizedEmail == normalized, cancellationToken))
                return new() { Failure = AuthFailure.GoogleConflict };
            user = new User(identity.Email, identity.DisplayName);
            user.SetGoogleSubject(identity.Subject);
            db.Users.Add(user);
        }
        var response = CreateSession(user);
        try { await db.SaveChangesAsync(cancellationToken); }
        catch (DbUpdateException)
        {
            // Same-sub or same-email concurrent signup: never attach based on email.
            db.ChangeTracker.Clear();
            user = await db.Users.SingleOrDefaultAsync(x => x.GoogleSubject == identity.Subject, cancellationToken);
            if (user is not null)
            {
                response = CreateSession(user);
                await db.SaveChangesAsync(cancellationToken);
            }
            else if (await db.Users.AnyAsync(x => x.NormalizedEmail == User.NormalizeEmail(identity.Email), cancellationToken))
                return new() { Failure = AuthFailure.GoogleConflict };
            else throw;
        }
        logger.LogInformation("Google authentication succeeded for user {UserId}.", user.Id);
        return new() { Response = response };
    }

    public async Task<AuthOutcome> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken)
    {
        var errors = AuthValidation.Registration(request);
        if (errors.Count > 0) return new() { Failure = AuthFailure.InvalidInput, Errors = errors };
        var normalized = User.NormalizeEmail(request.Email!);
        if (await db.Users.AnyAsync(x => x.NormalizedEmail == normalized, cancellationToken))
            return new() { Failure = AuthFailure.DuplicateEmail };

        var user = new User(request.Email!.Trim(), request.DisplayName!.Trim());
        user.SetPasswordHash(passwordHasher.HashPassword(user, request.Password!));
        db.Users.Add(user);
        var response = CreateSession(user);
        try
        {
            // User and initial refresh token are committed atomically by SaveChanges.
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException)
        {
            db.ChangeTracker.Clear();
            // Handles the unique-email race without parsing/logging provider error details.
            if (await db.Users.AnyAsync(x => x.NormalizedEmail == normalized, cancellationToken))
                return new() { Failure = AuthFailure.DuplicateEmail };
            throw;
        }
        logger.LogInformation("Auth registration succeeded for user {UserId}.", user.Id);
        return new() { Response = response };
    }

    public async Task<AuthOutcome> LoginAsync(LoginRequest request, CancellationToken cancellationToken)
    {
        if (!AuthValidation.ValidEmail(request.Email) || request.Password is null || request.Password.Length is < 1 or > 128)
            return Invalid();
        var normalized = User.NormalizeEmail(request.Email!);
        var user = await db.Users.SingleOrDefaultAsync(x => x.NormalizedEmail == normalized, cancellationToken);
        var hash = user?.PasswordHash ?? timingHash.Hash;
        var verified = passwordHasher.VerifyHashedPassword(user ?? timingHash.User, hash, request.Password);
        if (user?.PasswordHash is null || verified == PasswordVerificationResult.Failed)
        {
            logger.LogInformation("Auth login failed.");
            return Invalid();
        }
        if (verified == PasswordVerificationResult.SuccessRehashNeeded)
            user.SetPasswordHash(passwordHasher.HashPassword(user, request.Password));

        var response = CreateSession(user);
        await db.SaveChangesAsync(cancellationToken);
        logger.LogInformation("Auth login succeeded for user {UserId}.", user.Id);
        return new() { Response = response };
    }

    public async Task<AuthOutcome> RefreshAsync(string? raw, CancellationToken cancellationToken)
    {
        if (!RefreshTokenSecrets.IsValid(raw)) return Invalid();
        var hash = RefreshTokenSecrets.Hash(raw!);
        var existing = await db.RefreshTokens.AsNoTracking().SingleOrDefaultAsync(x => x.TokenHash == hash, cancellationToken);
        if (existing is null) return Invalid();

        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        await LockFamilyAsync(existing.FamilyId, cancellationToken);
        // Read again after acquiring the family lock; never act on pre-lock state.
        var old = await db.RefreshTokens.SingleAsync(x => x.Id == existing.Id, cancellationToken);
        var now = clock.GetUtcNow().UtcDateTime;
        if (old.RevokedAtUtc is not null)
        {
            await RevokeFamilyAsync(old.FamilyId, now, cancellationToken);
            await transaction.CommitAsync(cancellationToken);
            logger.LogWarning("Auth refresh replay rejected for user {UserId}.", old.UserId);
            return Invalid();
        }
        if (old.ExpiresAtUtc <= now) return Invalid();

        var user = await db.Users.SingleAsync(x => x.Id == old.UserId, cancellationToken);
        var newRaw = RefreshTokenSecrets.Generate();
        var next = new RefreshToken(user.Id, RefreshTokenSecrets.Hash(newRaw), now,
            now.AddDays(options.Value.RefreshTokenDays), old.FamilyId);
        // Persist successor first so the self-FK is satisfied, still inside this transaction.
        db.RefreshTokens.Add(next);
        await db.SaveChangesAsync(cancellationToken);
        old.Revoke(now, next.Id);
        try
        {
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateConcurrencyException)
        {
            await transaction.RollbackAsync(cancellationToken);
            logger.LogInformation("Auth concurrent refresh rejected.");
            return Invalid();
        }
        var response = Response(user, newRaw, next.ExpiresAtUtc);
        await transaction.CommitAsync(cancellationToken);
        logger.LogInformation("Auth refresh succeeded for user {UserId}.", user.Id);
        return new() { Response = response };
    }

    public async Task LogoutAsync(string? raw, CancellationToken cancellationToken)
    {
        if (!RefreshTokenSecrets.IsValid(raw)) return;
        var hash = RefreshTokenSecrets.Hash(raw!);
        var token = await db.RefreshTokens.AsNoTracking().SingleOrDefaultAsync(x => x.TokenHash == hash, cancellationToken);
        if (token is null) return;
        await using var transaction = await db.Database.BeginTransactionAsync(cancellationToken);
        await LockFamilyAsync(token.FamilyId, cancellationToken);
        await RevokeFamilyAsync(token.FamilyId, clock.GetUtcNow().UtcDateTime, cancellationToken);
        await transaction.CommitAsync(cancellationToken);
        logger.LogInformation("Auth logout completed for user {UserId}.", token.UserId);
    }

    public Task<UserProfile?> GetUserAsync(Guid userId, CancellationToken cancellationToken) =>
        db.Users.AsNoTracking().Where(x => x.Id == userId)
            .Select(x => new UserProfile(x.Id, x.DisplayName, x.Email, x.GoogleSubject != null)).SingleOrDefaultAsync(cancellationToken);

    private AuthResponse CreateSession(User user)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var raw = RefreshTokenSecrets.Generate();
        var token = new RefreshToken(user.Id, RefreshTokenSecrets.Hash(raw), now, now.AddDays(options.Value.RefreshTokenDays));
        db.RefreshTokens.Add(token);
        return Response(user, raw, token.ExpiresAtUtc);
    }

    private AuthResponse Response(User user, string raw, DateTime expires)
    {
        var access = tokenIssuer.Issue(user.Id);
        return new AuthResponse
        {
            AccessToken = access.Value,
            AccessTokenExpiresAtUtc = access.ExpiresAtUtc,
            RefreshToken = raw,
            RefreshTokenExpiresAtUtc = expires,
            User = new UserProfile(user.Id, user.DisplayName, user.Email, user.GoogleSubject != null)
        };
    }

    private async Task LockFamilyAsync(Guid familyId, CancellationToken cancellationToken)
    {
        if (db.Database.IsNpgsql())
        {
            // All rotations/logout/replays lock the immutable root row, including after it is revoked.
            // This serializes a session across application instances at PostgreSQL READ COMMITTED.
            var roots = await db.RefreshTokens.FromSqlInterpolated(
                $"SELECT * FROM \"RefreshTokens\" WHERE \"Id\" = {familyId} FOR UPDATE")
                .AsNoTracking().ToListAsync(cancellationToken);
            if (roots.Count != 1)
                throw new InvalidOperationException("Refresh session root is missing.");
        }
        if (!db.Database.IsNpgsql() && db.Database.ProviderName != "Microsoft.EntityFrameworkCore.Sqlite")
            throw new NotSupportedException("Unsupported authentication database provider.");
        // SQLite is test-only; its write transaction serializes writers. The concurrency token remains
        // a second guard. Other providers are unsupported.
    }

    private Task<int> RevokeFamilyAsync(Guid familyId, DateTime now, CancellationToken cancellationToken) =>
        db.RefreshTokens.Where(x => x.FamilyId == familyId && x.RevokedAtUtc == null)
            .ExecuteUpdateAsync(setters => setters.SetProperty(x => x.RevokedAtUtc, now), cancellationToken);

    private static AuthOutcome Invalid() => new() { Failure = AuthFailure.InvalidCredentials };
}


