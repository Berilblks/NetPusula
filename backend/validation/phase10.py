"""Disposable PostgreSQL 16 + actual Kestrel hardening checks. No external packages.

Run from any directory: python -X utf8 backend/validation/phase10.py setup|check|cleanup
Runtime secrets stay in ignored backend/obj/phase10 and are removed by cleanup.
Only the uniquely named container created by setup is eligible for cleanup.
"""
import base64, concurrent.futures, datetime, hashlib, hmac, json, os, pathlib
import secrets, statistics, subprocess, sys, time, urllib.request, urllib.error, uuid
from decimal import Decimal, localcontext

ROOT = pathlib.Path(__file__).resolve().parents[1]
WORK = ROOT / 'obj' / 'phase10'
STATE = WORK / 'runtime.json'
RESULT = WORK / 'results.json'
BASE = 'http://127.0.0.1:5080'
ALES = '00000000-0000-0000-0000-000000000003'
TODAY = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=3))).date()
report = {}

def run(args, **kw):
    p = subprocess.run(args, capture_output=True, text=True, encoding='utf-8', errors='replace', **kw)
    if p.returncode:
        raise RuntimeError('Command failed: ' + args[0])  # never echo secrets/SQL errors
    return p.stdout.strip()

def state(): return json.loads(STATE.read_text(encoding='utf-8'))
def save(s): STATE.write_text(json.dumps(s), encoding='utf-8')
def sql(query):
    return run(['docker','exec','-i',state()['container'],'psql','-U','phase10','-d','phase10','-At','-v','ON_ERROR_STOP=1'], input=query)

def http(path, method='GET', body=None, token=None, expected=200, base=BASE, extra=None):
    headers = {'Content-Type':'application/json'}
    if token: headers['Authorization'] = 'Bearer '+token
    headers.update(extra or {})
    data = json.dumps(body,ensure_ascii=False).encode() if body is not None else None
    req = urllib.request.Request(base+path,data=data,headers=headers,method=method)
    try: response = urllib.request.urlopen(req,timeout=30)
    except urllib.error.HTTPError as e: response = e
    raw = response.read()
    if expected is not None:
        assert response.status == expected, f'{method} {path}: expected {expected}, got {response.status}'
    if path.startswith(('/api/auth','/api/user-exams','/api/mock-exams','/api/dashboard','/api/statistics')):
        assert 'no-store' in response.headers.get('Cache-Control',''), path+' cache'
    obj = json.loads(raw) if raw else None
    if response.status >= 400:
        assert not any(x in raw.decode().lower() for x in ('stacktrace','npgsql','exception:','passwordhash','tokenhash'))
    return obj, response.status, dict(response.headers)

def get(path, token): return http(path,token=token)[0]
def login(email=None):
    s=state(); return http('/api/auth/login','POST',{'email':email or s['email'],'password':s['password']})[0]
def prep(token, target=80):
    return http('/api/user-exams','POST',{'examId':ALES,'targetNet':target,'examDate':str(TODAY+datetime.timedelta(days=30))},token,201)[0]
def mock(token, correct=20, wrong=4, name='Deneme — ölçüm'):
    return {'name':name,'takenAt':str(TODAY),'notes':None,'results':[
        {'examSectionId':s['id'],'correctCount':correct,'wrongCount':wrong}
        for s in get('/api/exams/'+ALES+'/sections',token)]}
def create(token, body=None): return http('/api/mock-exams','POST',body or mock(token),token,201)[0]
def parallel(fn, count=8):
    with concurrent.futures.ThreadPoolExecutor(max_workers=count) as pool: return list(pool.map(fn,range(count)))
def mark(name, value=True):
    report[name]=value; RESULT.write_text(json.dumps(report,indent=2),encoding='utf-8'); print('PASS '+name,flush=True)

def start_api(s, port=5080, limit=1000):
    env=os.environ.copy(); env.update(s['env']); env['ASPNETCORE_URLS']=f'http://0.0.0.0:{port}'
    env['AuthRateLimit__PermitLimit']=str(limit)
    log=open(WORK/f'api-{port}.log','w',encoding='utf-8')
    p=subprocess.Popen(['dotnet',str(ROOT/'src/NetPusula.Api/bin/Debug/net8.0/NetPusula.Api.dll')],cwd=ROOT,env=env,stdout=log,stderr=log)
    for _ in range(150):
        try:
            urllib.request.urlopen(f'http://127.0.0.1:{port}/api/health',timeout=1).close(); return p.pid
        except (OSError,urllib.error.URLError):
            if p.poll() is not None: raise RuntimeError('Isolated API startup failed; inspect redacted log locally')
            time.sleep(.2)
    raise RuntimeError('Isolated API did not start')

def setup():
    assert not STATE.exists(), 'Run cleanup before creating another environment'
    WORK.mkdir(parents=True,exist_ok=True)
    password=secrets.token_hex(24); key=base64.b64encode(secrets.token_bytes(48)).decode()
    name='netpusula-phase10-'+secrets.token_hex(5)
    s={'container':name,'pids':[],'password':secrets.token_hex(18)+'A7','email':'phase10-a@example.test',
       'env':{'ConnectionStrings__Database':f'Host=127.0.0.1;Port=55440;Database=phase10;Username=phase10;Password={password}',
       'Jwt__SigningKey':key,'Jwt__Issuer':'NetPusula','Jwt__Audience':'NetPusula.Mobile',
       'ASPNETCORE_ENVIRONMENT':'Development','AllowedHosts':'localhost;127.0.0.1;10.0.2.2',
       'Logging__LogLevel__Default':'Critical','Logging__LogLevel__Microsoft':'Critical'}}
    save(s)
    env=os.environ.copy();env['POSTGRES_PASSWORD']=password
    s['containerId']=run(['docker','run','-d','--name',name,'-p','127.0.0.1:55440:5432','-e','POSTGRES_PASSWORD','-e','POSTGRES_USER=phase10','-e','POSTGRES_DB=phase10','postgres:16','-c','shared_preload_libraries=pg_stat_statements'],env=env)
    save(s)
    for _ in range(100):
        try: sql('SELECT 1;'); break
        except RuntimeError: time.sleep(.2)
    env.update(s['env'])
    for i in range(2):
        output=run(['dotnet','ef','database','update','--project','src/NetPusula.Infrastructure'],cwd=ROOT,env=env)
        (WORK/f'migrations-{i}.log').write_text(output,encoding='utf-8')
    sql('CREATE EXTENSION pg_stat_statements;')
    s['pids'].append(start_api(s)); save(s)
    print('Disposable PostgreSQL16 and API ready; secrets omitted')

def check():
    s=state(); token=None
    assert sql('SELECT count(*) FROM "__EFMigrationsHistory"')=='4'
    indexes=sql("SELECT indexdef FROM pg_indexes WHERE schemaname='public'")
    assert 'UX_UserExams_OneActivePerUser' in indexes and 'WHERE ("IsActive" = true)' in indexes
    assert int(sql("SELECT count(*) FROM pg_constraint WHERE contype='f' AND confdeltype='r'"))>=8
    mark('migrations_schema')
    for suffix in ('a','b'):
        http('/api/auth/register','POST',{'displayName':'Doğrulama '+suffix,'email':f'phase10-{suffix}@example.test','password':s['password']},expected=201)
    a=login(); b=login('phase10-b@example.test'); token=a['accessToken']; bt=b['accessToken']; uid=a['user']['id']
    assert get('/api/auth/me',token)['id']==uid
    http('/api/auth/register','POST',{'displayName':'Test','email':'PHASE10-A@EXAMPLE.TEST','password':s['password']},expected=409)
    assert login(' PHASE10-A@EXAMPLE.TEST ')['user']['id']==uid
    for email,password in [('bad','bad'),('x'*300,'1'),('',''),('a@example.test','short')]:
        http('/api/auth/register','POST',{'displayName':'Test','email':email,'password':password},expected=400)
    wrong=http('/api/auth/login','POST',{'email':s['email'],'password':'Invalid example 7'},expected=401)[0]
    unknown=http('/api/auth/login','POST',{'email':'unknown@example.test','password':'Invalid example 7'},expected=401)[0]
    assert wrong==unknown
    for path in ['/api/auth/me','/api/user-exams/active','/api/mock-exams','/api/dashboard','/api/statistics']:
        http(path,expected=401); http(path,token='malformed',expected=401)
    def forged(**changes):
        enc=lambda x:base64.urlsafe_b64encode(json.dumps(x).encode()).rstrip(b'=')
        claims={'sub':uid,'iss':'NetPusula','aud':'NetPusula.Mobile','exp':int(time.time())+600};claims.update(changes)
        data=enc({'alg':'HS256','typ':'JWT'})+b'.'+enc(claims)
        key=base64.b64decode(s['env']['Jwt__SigningKey'])
        return (data+b'.'+base64.urlsafe_b64encode(hmac.new(key,data,hashlib.sha256).digest()).rstrip(b'=')).decode()
    for jwt in [forged(exp=int(time.time())-10),forged(iss='other'),forged(aud='other'),forged()[:-8]+'AAAAAAAA']:
        http('/api/auth/me',token=jwt,expected=401)
    for refresh in ['malformed','A'*64]: http('/api/auth/refresh','POST',{'refreshToken':refresh},expected=401)
    rotated=http('/api/auth/refresh','POST',{'refreshToken':a['refreshToken']})[0]
    http('/api/auth/refresh','POST',{'refreshToken':a['refreshToken']},expected=401)
    http('/api/auth/refresh','POST',{'refreshToken':rotated['refreshToken']},expected=401)
    expired=login(); digest=hashlib.sha256(expired['refreshToken'].encode()).hexdigest().upper()
    sql(f'''UPDATE "RefreshTokens" SET "CreatedAtUtc"=now()-interval '2 days',"ExpiresAtUtc"=now()-interval '1 day' WHERE "TokenHash"='{digest}';''')
    http('/api/auth/refresh','POST',{'refreshToken':expired['refreshToken']},expected=401)
    mark('authentication_adversarial')
    pa=prep(token); pb=prep(bt); m=create(token); mid=m['id']
    for name,query in [
        ('restrict',f'''DELETE FROM "Users" WHERE "Id"='{uid}';'''),
        ('counts','UPDATE "MockExamResults" SET "CorrectCount"=-1;'),
        ('foreign_key', '''UPDATE "MockExamResults" SET "MockExamId"='11111111-1111-1111-1111-111111111111';''')]:
        try: sql('BEGIN;'+query+'ROLLBACK;')
        except RuntimeError: pass
        else: raise AssertionError('Constraint allowed '+name)
    for method in ['GET','PUT','DELETE']:
        http('/api/mock-exams/'+mid,method,mock(bt) if method=='PUT' else None,bt,404)
    http('/api/user-exams/'+pa['id'],'PUT',{'targetNet':70,'examDate':str(TODAY)},bt,404)
    assert get('/api/mock-exams',bt)['totalCount']==0
    assert get('/api/statistics',bt)['summary']['attemptCount']==0
    for field in ['userId','userExamId','net','totalNet','createdAtUtc','familyId']:
        body=mock(token);body[field]=str(uuid.uuid4());http('/api/mock-exams','POST',body,token,400)
    for body in [dict(mock(token),name='x'*201),dict(mock(token),takenAt=str(TODAY+datetime.timedelta(days=1))),dict(mock(token),results=[])]:
        http('/api/mock-exams','POST',body,token,400)
    for count in [-1,1.5,51,2147483647]:
        body=mock(token);body['results'][0]['correctCount']=count;http('/api/mock-exams','POST',body,token,400)
    for query in ['range=bad','range=5&range=10','userId='+uid,'userExamId='+pa['id']]:
        http('/api/statistics?'+query,token=token,expected=400)
    http('/api/mock-exams/'+mid,'PUT',mock(token,21,3,'Düzenlendi'),token)
    assert get('/api/mock-exams/'+mid,token)['name']=='Düzenlendi'
    get('/api/dashboard',token); get('/api/statistics',token)
    http('/api/mock-exams/'+mid,'DELETE',token=token,expected=204)
    http('/api/mock-exams/'+mid,token=token,expected=404)
    mark('e2e_idor_input_contract')
    parallel(lambda i:prep(token,60+i))
    assert sql(f'''SELECT count(*) FROM "UserExams" WHERE "UserId"='{uid}' AND "IsActive"''')=='1'
    fresh=login(); statuses=parallel(lambda _:http('/api/auth/refresh','POST',{'refreshToken':fresh['refreshToken']},expected=None)[1])
    assert statuses.count(200)==1 and statuses.count(401)==7
    refresh_statuses=statuses
    digest=hashlib.sha256(fresh['refreshToken'].encode()).hexdigest().upper()
    assert sql(f'''SELECT count(*) FROM "RefreshTokens" WHERE "FamilyId"=(SELECT "FamilyId" FROM "RefreshTokens" WHERE "TokenHash"='{digest}') AND "RevokedAtUtc" IS NULL''')=='0'
    duplicates=parallel(lambda _:create(token),4); assert len({m['id'] for m in duplicates})==4
    mid=duplicates[0]['id']
    statuses=parallel(lambda i:http('/api/mock-exams/'+mid,'PUT' if i%2 else 'DELETE',mock(token) if i%2 else None,token,expected=None)[1])
    assert set(statuses)<= {200,204,404}
    assert sql('''SELECT count(*) FROM "MockExamResults" r LEFT JOIN "MockExams" m ON r."MockExamId"=m."Id" WHERE m."Id" IS NULL''')=='0'
    mark('concurrency',{'refreshStatuses':refresh_statuses,'editDeleteStatuses':statuses,'duplicatePostsCreateDistinctRecords':True})
    # Faults run only in this disposable DB and are removed even when assertions fail.
    def fault(table, event, action, invariant):
        sql(f'''CREATE FUNCTION phase10_fault() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'controlled validation failure'; END $$;
        CREATE TRIGGER phase10_fault BEFORE {event} ON "{table}" FOR EACH ROW EXECUTE FUNCTION phase10_fault();''')
        try:
            result=action();assert result[1]==500
            assert result[2].get('Content-Type','').startswith('application/problem+json')
            invariant()
        finally: sql(f'DROP TRIGGER phase10_fault ON "{table}"; DROP FUNCTION phase10_fault();')
    def equal(actual,expected): assert actual==expected
    before=get('/api/user-exams/active',token)
    fault('UserExams','INSERT',lambda:http('/api/user-exams','POST',{'examId':ALES,'targetNet':99,'examDate':str(TODAY)},token,expected=None),lambda:equal(get('/api/user-exams/active',token),before))
    count=get('/api/mock-exams',token)['totalCount']
    fault('MockExamResults','INSERT',lambda:http('/api/mock-exams','POST',mock(token),token,expected=None),lambda:equal(get('/api/mock-exams',token)['totalCount'],count))
    m=create(token);mid=m['id']
    fault('MockExamResults','UPDATE',lambda:http('/api/mock-exams/'+mid,'PUT',mock(token,30,1,'Must rollback'),token,expected=None),lambda:equal(get('/api/mock-exams/'+mid,token),m))
    fault('MockExams','DELETE',lambda:http('/api/mock-exams/'+mid,'DELETE',token=token,expected=None),lambda:equal(get('/api/mock-exams/'+mid,token),m))
    fresh=login();digest=hashlib.sha256(fresh['refreshToken'].encode()).hexdigest().upper()
    before_count=sql('SELECT count(*) FROM "RefreshTokens"')
    fault('RefreshTokens','UPDATE',lambda:http('/api/auth/refresh','POST',{'refreshToken':fresh['refreshToken']},expected=None),lambda:equal(sql('SELECT count(*) FROM "RefreshTokens"'),before_count))
    next_token=http('/api/auth/refresh','POST',{'refreshToken':fresh['refreshToken']})[0]['refreshToken']
    fault('RefreshTokens','UPDATE',lambda:http('/api/auth/logout','POST',{'refreshToken':next_token},expected=None),lambda:equal(sql(f'''SELECT "RevokedAtUtc" IS NULL FROM "RefreshTokens" WHERE "TokenHash"='{hashlib.sha256(next_token.encode()).hexdigest().upper()}' '''),'t'))
    http('/api/auth/logout','POST',{'refreshToken':next_token},expected=204)
    http('/api/auth/refresh','POST',{'refreshToken':next_token},expected=401)
    mark('atomic_failure_rollback')
    prep(token,80)
    for divisor in [3,4,8]:
        sql(f'''UPDATE "ExamSections" SET "PenaltyDivisor"={divisor} WHERE "ExamId"='{ALES}';''')
        for correct,wrong in [(20,1),(0,0),(0,1)]:
            m=create(token,mock(token,correct,wrong))
            for r in m['results']:
                assert isinstance(r['net'],str)
                with localcontext() as ctx:
                    ctx.prec=29
                    assert abs(Decimal(r['net'])-(Decimal(correct)-Decimal(wrong)/Decimal(divisor))) < Decimal('0.00000000000000000000000001')
    sql(f'''UPDATE "ExamSections" SET "PenaltyDivisor"=4 WHERE "ExamId"='{ALES}';''')
    stats=get('/api/statistics?range=all',token)
    assert stats['activity']['averageDaysBetweenMocks']=='0'
    assert stats['improvement']['sufficientData']
    mark('decimal_3_4_8_same_day_comparison')
    # Bounded real-data measurement; independent POSTs intentionally have no idempotency key.
    prep(token,81)
    for batch in range(50): parallel(lambda i:create(token,mock(token,20+(i%5),4,'Perf')),10)
    perf={}
    for path,expected_commands in [('/api/dashboard',3),('/api/statistics?range=all',4),('/api/statistics?range=5',4),('/api/mock-exams?pageSize=100',4)]:
        get(path,token);times=[]
        for _ in range(5):
            sql('SELECT pg_stat_statements_reset();');start=time.perf_counter();data=get(path,token);times.append((time.perf_counter()-start)*1000)
            commands=int(sql("SELECT coalesce(sum(calls),0) FROM pg_stat_statements WHERE query LIKE 'SELECT%' AND query NOT LIKE '%pg_stat_statements%' AND query NOT LIKE '%pg_catalog%'"))
            assert commands==expected_commands, (path,commands)
        perf[path]={'medianMs':round(statistics.median(times),2),'selectCommands':commands}
    for selection,n in [('5',5),('10',10),('20',20),('all',500)]:
        stats=get('/api/statistics?range='+selection,token);assert stats['summary']['attemptCount']==n
    assert get('/api/statistics',bt)['summary']['attemptCount']==0
    mark('500_mock_performance',perf)
    # A separate listener/window prevents the test workload from consuming rate-test permits.
    pid=start_api(s,5081,2);s['pids'].append(pid);save(s)
    http('/api/auth/login','POST',{},expected=401,base='http://127.0.0.1:5081')
    http('/api/auth/refresh','POST',{'refreshToken':'bad'},expected=401,base='http://127.0.0.1:5081')
    _,_,headers=http('/api/auth/register','POST',{},expected=429,base='http://127.0.0.1:5081',extra={'X-Forwarded-For':'203.0.113.77'})
    assert headers.get('Retry-After');mark('real_http_shared_rate_limit')
    print('All real PostgreSQL/HTTP checks passed. Environment retained for emulator smoke.')

def read_race():
    """A DB lock is a deterministic barrier between the parent and child SELECTs."""
    s=state()
    http('/api/auth/register','POST',{'displayName':'Race','email':'race@example.test','password':s['password']},expected=None)
    token=login('race@example.test')['accessToken'];prep(token)
    for listing in [False,True]:
        m=create(token,mock(token,20,4,'Before'));mid=m['id']
        holder=subprocess.Popen(['docker','exec','-i',s['container'],'psql','-U','phase10','-d','phase10','-At','-v','ON_ERROR_STOP=1'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,encoding='utf-8')
        holder.stdin.write('BEGIN; LOCK TABLE "MockExamResults" IN ACCESS EXCLUSIVE MODE;\n\\echo LOCKED\n');holder.stdin.flush()
        while holder.stdout.readline().strip()!='LOCKED':
            assert holder.poll() is None
        try:
            with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
                future=pool.submit(get,'/api/mock-exams' if listing else '/api/mock-exams/'+mid,token)
                deadline=time.monotonic()+15
                while sql("SELECT count(*) FROM pg_stat_activity WHERE wait_event_type='Lock' AND query LIKE 'SELECT%' AND query LIKE '%MockExamResults%'")=='0':
                    assert time.monotonic()<deadline,'Reader did not reach barrier'
                    time.sleep(.02)
                holder.stdin.write(f'''UPDATE "MockExams" SET "Name"='After' WHERE "Id"='{mid}'; UPDATE "MockExamResults" SET "CorrectCount"=30,"BlankCount"="QuestionCountSnapshot"-34 WHERE "MockExamId"='{mid}'; COMMIT;\n\\q\n''');holder.stdin.flush()
                result=future.result(timeout=15)
            row=next(x for x in result['items'] if x['id']==mid) if listing else result
            assert (row['name'],Decimal(row['totalNet']))==('Before',Decimal(38)), 'Mixed parent/result versions in '+('history' if listing else 'detail')
        finally:
            if holder.poll() is None:
                holder.stdin.close();holder.wait(timeout=10)
    print('PASS deterministic detail/history read consistency')

def cleanup():
    s=state();assert s['container'].startswith('netpusula-phase10-')
    assert run(['docker','inspect','--format','{{.Id}}',s['container']])==s['containerId']
    for pid in s['pids']:
        # A reused PID must never stop an unrelated process after a later cleanup.
        command=f'$p=Get-CimInstance Win32_Process -Filter "ProcessId = {int(pid)}"; if ($p.CommandLine -like "*NetPusula.Api/bin/Debug/net8.0/NetPusula.Api.dll*" -or $p.CommandLine -like "*NetPusula.Api\\bin\\Debug\\net8.0\\NetPusula.Api.dll*") {{ Stop-Process -Id {int(pid)} -Force }}'
        run(['powershell','-NoProfile','-Command',command])
    run(['docker','rm','-f','-v',s['container']])
    STATE.unlink();print('Only owned validation API/container removed; runtime secrets deleted')

if __name__=='__main__':
    {'setup':setup,'check':check,'race':read_race,'cleanup':cleanup}[sys.argv[1]]()
