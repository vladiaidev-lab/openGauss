#include <cstdio>
#include <cstdlib>
#include <sql.h>
#include <sqlext.h>

static void check(SQLRETURN rc, const char* msg,
                  SQLSMALLINT htype, SQLHANDLE h) {
    if (rc == SQL_SUCCESS || rc == SQL_SUCCESS_WITH_INFO) return;
    SQLCHAR state[6], text[256];
    SQLINTEGER native;
    SQLSMALLINT len;
    SQLGetDiagRec(htype, h, 1, state, &native, text, sizeof(text), &len);
    std::fprintf(stderr, "%s  SQLSTATE=%s  %s\n", msg, state, text);
    std::exit(1);
}

int main() {
    SQLHENV   env  = SQL_NULL_HENV;
    SQLHDBC   dbc  = SQL_NULL_HDBC;
    SQLHSTMT  stmt = SQL_NULL_HSTMT;
    SQLRETURN rc;

    rc = SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &env);
    check(rc, "AllocEnv", SQL_HANDLE_ENV, env);
    SQLSetEnvAttr(env, SQL_ATTR_ODBC_VERSION, (void*)SQL_OV_ODBC3, 0);

    rc = SQLAllocHandle(SQL_HANDLE_DBC, env, &dbc);
    check(rc, "AllocDbc", SQL_HANDLE_DBC, dbc);

    rc = SQLConnect(dbc,
                    (SQLCHAR*)"openGaussDev", SQL_NTS,
                    (SQLCHAR*)"omm",          SQL_NTS,
                    (SQLCHAR*)"Dev@12345",    SQL_NTS);
    check(rc, "Connect", SQL_HANDLE_DBC, dbc);
    std::printf("Connected to openGauss!\n");

    rc = SQLAllocHandle(SQL_HANDLE_STMT, dbc, &stmt);
    check(rc, "AllocStmt", SQL_HANDLE_STMT, stmt);

    rc = SQLExecDirect(stmt, (SQLCHAR*)"SELECT version();", SQL_NTS);
    check(rc, "ExecDirect", SQL_HANDLE_STMT, stmt);

    SQLCHAR version[512];
    SQLLEN  ind;
    if (SQLFetch(stmt) == SQL_SUCCESS) {
        SQLGetData(stmt, 1, SQL_C_CHAR, version, sizeof(version), &ind);
        std::printf("Server version: %s\n", version);
    }

    SQLFreeHandle(SQL_HANDLE_STMT, stmt);
    SQLDisconnect(dbc);
    SQLFreeHandle(SQL_HANDLE_DBC,  dbc);
    SQLFreeHandle(SQL_HANDLE_ENV,  env);
    return 0;
}
