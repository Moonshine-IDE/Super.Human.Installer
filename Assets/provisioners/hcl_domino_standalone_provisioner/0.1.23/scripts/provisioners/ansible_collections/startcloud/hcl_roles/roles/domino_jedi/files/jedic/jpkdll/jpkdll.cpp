// jpkdll.cpp : Defines the entry point for the DLL application.
//

#include "stdafx.h"

#include "Win32PKDll.h"

using namespace std;

BOOL APIENTRY DllMain( HANDLE hModule, 
					  DWORD  ul_reason_for_call, 
					  LPVOID lpReserved
					  )
{
    switch (ul_reason_for_call)
	{
	case DLL_PROCESS_ATTACH:
	case DLL_THREAD_ATTACH:
	case DLL_THREAD_DETACH:
	case DLL_PROCESS_DETACH:
		break;
    }
	
    return TRUE;
}

//
// HELPERS
//

enum jpk_dll_errors
{
	ok = 0, internal_error,
		param_errors, 
		can_not_enumerate_windows,
		can_not_enumerate_processes,
		no_window_for_app_name,
		can_not_open_process_for_pid,
		can_not_kill,
		can_not_start_snapshot,
		can_not_iterate_snapshot,
		not_enough_memory,
		can_not_create_array
};

//
// jni throw exception function
//
static void setException(JNIEnv * jnienv, int nErrorCode, int dwWinCode, int nLine)
{
	if (!jnienv->ExceptionOccurred())
	{
		jclass exceptClass;
		exceptClass = jnienv->FindClass("java/io/IOException");
		static char szBuffer[128];
		sprintf(szBuffer, "%d|%u|%d", nErrorCode, dwWinCode, nLine);
		jnienv->ThrowNew(exceptClass, szBuffer);
	}
}

//
// light utility class for processes snapshot
// used mainly to eliminate code repetion and accurate cleanup via destructor
//
struct CProcsSnapshot
{
public:
	struct __proc_hier__;

public:
	// snapshot handle
	HANDLE	m_hSnapshot;
	
	// Win32 last error (as doubleword)
	DWORD m_dwWin32Error;
	
	// etc
	PROCESSENTRY32 m_pe32;

	__proc_hier__ * m_pProcSet;
	int m_nMaxProcSetLen;
	int m_nProcSetLen;
	
public:
	static const int g_nMaxPIDs;

	CProcsSnapshot();
	virtual ~CProcsSnapshot();

	// Snapshot
	bool StartSnapshot(void);
	void EndSnapshot(void);

	bool FirstSnapshotEntry(void);
	bool NextSnapshotEntry(void);

	// Tree
	bool AllocTree(int nEntries);
	void DeallocTree(void);
	bool CreateTree(void);

	int GetTreeLen(DWORD dwRoot);

	bool Kill(DWORD dwPid);
	void KillTree(DWORD dwRoot, long& nAll, long& nKilled);

	int StoreTree(DWORD dwRoot, JNIEnv * jnienv, jintArray jarr, int nIndex);

	// accessors
public:
	DWORD getWin32Error(void) const { return m_dwWin32Error; }
	
public:
	int count_rooted(CProcsSnapshot::__proc_hier__ * pProcSet, int nProcSetLen, 
		DWORD dwRootPid);
	int kill_rooted(CProcsSnapshot::__proc_hier__ * pProcSet, int nProcSetLen, 
		DWORD dwRootPid, UINT uExitCode);
	
	struct __proc_hier__
	{
		DWORD dwPid;
		DWORD dwParentPid;
	};
};

const int CProcsSnapshot::g_nMaxPIDs = 100;

CProcsSnapshot::CProcsSnapshot()
{
	m_hSnapshot = INVALID_HANDLE_VALUE;
	m_dwWin32Error = 0;

	memset(&m_pe32, 0, sizeof m_pe32);
	m_pe32.dwSize = sizeof m_pe32;

	m_pProcSet = 0;
	m_nProcSetLen = 0;
}

CProcsSnapshot::~CProcsSnapshot()
{
	EndSnapshot();
	DeallocTree();
}

bool CProcsSnapshot::StartSnapshot(void)
{
	// reset last error
	m_dwWin32Error = 0;
	
	// attempt snapshot
	m_hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	bool bSuccess = (m_hSnapshot != INVALID_HANDLE_VALUE);
	if (!bSuccess)
	{
		// store Win32 error
		m_dwWin32Error = GetLastError();
	}
	return (bSuccess);
}

void CProcsSnapshot::EndSnapshot(void)
{
	// rest last error
	m_dwWin32Error = 0;
	
	// close handle if still valid
	if (m_hSnapshot != INVALID_HANDLE_VALUE)
	{
		CloseHandle(m_hSnapshot);
		// store Win32 error
		m_dwWin32Error = GetLastError();
	}
	
	m_hSnapshot = INVALID_HANDLE_VALUE;
}

bool CProcsSnapshot::FirstSnapshotEntry(void)
{
	// rest last error
	m_dwWin32Error = 0;

	memset(&m_pe32, 0, sizeof m_pe32);
	m_pe32.dwSize = sizeof m_pe32;

	bool bOk = Process32First(m_hSnapshot, &m_pe32) > 0;
	if (!bOk)
		m_dwWin32Error = GetLastError();

	return bOk;
}

bool CProcsSnapshot::NextSnapshotEntry(void)
{
	// rest last error
	m_dwWin32Error = 0;

	memset(&m_pe32, 0, sizeof m_pe32);
	m_pe32.dwSize = sizeof m_pe32;

	bool bOk = Process32Next(m_hSnapshot, &m_pe32) > 0;
	if (!bOk)
		m_dwWin32Error = GetLastError();

	return bOk;
}

bool CProcsSnapshot::AllocTree(int nEntries)
{
	DeallocTree();
	if (nEntries < 0)
		return false;

	m_nMaxProcSetLen = nEntries;
	m_pProcSet = new __proc_hier__ [m_nMaxProcSetLen];
	m_nProcSetLen = 0;

	return (m_pProcSet != 0);
}

void CProcsSnapshot::DeallocTree(void)
{
	if (m_pProcSet != 0)
		delete [] m_pProcSet;

	m_pProcSet = 0;
	m_nProcSetLen = m_nMaxProcSetLen = 0;
}

bool CProcsSnapshot::CreateTree()
{
	if ((m_pProcSet == 0) && 
		AllocTree(CProcsSnapshot::g_nMaxPIDs))
		return false;

	// walk next snapshot entries
	for (m_nProcSetLen = 0; NextSnapshotEntry();)
	{
		if (m_nProcSetLen < m_nMaxProcSetLen)
		{
			m_pProcSet[m_nProcSetLen].dwPid = m_pe32.th32ProcessID;
			m_pProcSet[m_nProcSetLen].dwParentPid = m_pe32.th32ParentProcessID;
			m_nProcSetLen++;
		}
	}

	return true;
}

int CProcsSnapshot::GetTreeLen(DWORD dwRoot)
{
	if (m_pProcSet == 0)
		return 0;

	bool bFound = false;
	int nCount = 0;
	for (int i = 0; i < m_nProcSetLen; i++)
	{
		if (m_pProcSet[i].dwPid == dwRoot)
			bFound = true;

		if (m_pProcSet[i].dwParentPid == dwRoot)
			nCount += GetTreeLen(m_pProcSet[i].dwPid);
	}

	return bFound ? 1 + nCount : 0;
}

void CProcsSnapshot::KillTree(DWORD dwRoot, long& nAll, long& nKilled)
{
	if ((m_pProcSet == 0) && 
		AllocTree(CProcsSnapshot::g_nMaxPIDs) &&
		CreateTree())
		return;

	for (int i = 0; i < m_nProcSetLen; i++)
	{
		if (m_pProcSet[i].dwPid == dwRoot)
			nAll++;
		if (m_pProcSet[i].dwParentPid == dwRoot)
			KillTree(m_pProcSet[i].dwPid, nAll, nKilled);
	}

	if (Kill(dwRoot))
		nKilled++;

	return;
}

bool CProcsSnapshot::Kill(DWORD dwPID)
{
	// open process
	HANDLE hProcess = OpenProcess(PROCESS_TERMINATE, FALSE, dwPID);
	if (hProcess == NULL)
		return false;
	
	// attempt to terminate process
	UINT uExitCode = 0;
	BOOL bReturn = (TerminateProcess(hProcess, uExitCode) > 0);
	
	// clean up
	CloseHandle(hProcess);

	return (bReturn > 0);
}

int CProcsSnapshot::StoreTree(DWORD dwRoot, JNIEnv * jnienv, jintArray jarr, int nIndex)
{
	if ((m_pProcSet == 0) || (jnienv == 0) || (jarr == 0))
		return nIndex;

	for (int i = 0; i < m_nProcSetLen; i++)
	{
		if (m_pProcSet[i].dwPid == dwRoot)
		{
			jnienv->SetIntArrayRegion(jarr, nIndex++, 1, reinterpret_cast<long*>(&dwRoot));
		}

		if (m_pProcSet[i].dwParentPid == dwRoot)
			nIndex = StoreTree(m_pProcSet[i].dwPid, jnienv, jarr, nIndex);
	}

	return nIndex;
}

struct CWindowsList
{
	DWORD m_dwWin32Error;
	vector<string> m_Windows;
	bool DoEnumWindows();

	CWindowsList() { m_dwWin32Error = 0; } 

protected:
	static BOOL CALLBACK EnumWindowsProc(HWND hwnd, LPARAM lParam);
};

bool CWindowsList::DoEnumWindows()
{
	m_dwWin32Error = 0;
	m_Windows.clear();
	bool bResult = 
		EnumWindows(EnumWindowsProc, reinterpret_cast<LPARAM>(this)) > 0;
	if (!bResult)
		m_dwWin32Error = GetLastError();

	return bResult;
}

BOOL CALLBACK CWindowsList::EnumWindowsProc(HWND hwnd, LPARAM lParam)
{
	CWindowsList * pWS = reinterpret_cast<CWindowsList *> (lParam);
	if (lParam == 0)
		return FALSE;

	if (!IsWindowVisible(hwnd))
		return TRUE;

	const int nLen = GetWindowTextLength(hwnd);
	if (nLen > 0)
	{
		char szWindowText[256];
		GetWindowText(hwnd, szWindowText, sizeof szWindowText);
		pWS->m_Windows.push_back(szWindowText);
	}

	return TRUE;
}

/*
 * Class:     Win32PKDll
 * Method:    applications
 * Signature: ()[Ljava/lang/String;
 */
JNIEXPORT jobjectArray JNICALL Java_com_Prominic_jdi_system_Win32PKDll_applications
  (JNIEnv * jnienv, jobject)
{
	// paranoia ...
	if (jnienv == 0)
		return 0;

	// attempt windows/applications snapshot
	CWindowsList wl;
	if (!wl.DoEnumWindows())
	{
		setException(jnienv, can_not_enumerate_windows, wl.m_dwWin32Error, __LINE__);
		return 0;
	}

	int nWindows = wl.m_Windows.size();
	if (nWindows < 1)
	{
		setException(jnienv, internal_error, 0, __LINE__);
		return 0;
	}
	
	// create return array
	jobjectArray jarr = (jobjectArray) jnienv->NewObjectArray(
		nWindows, jnienv->FindClass("java/lang/String"),
		jnienv->NewStringUTF(""));

	if (jarr == 0)
	{
		setException(jnienv, can_not_create_array, 0, __LINE__);
		return 0;
	}

	// store application names
	for (int i = 0; i < nWindows; i++)
	{
		const char * pszWindowTitle = wl.m_Windows[i].c_str();
		if (pszWindowTitle == 0)
			pszWindowTitle = "";

		jnienv->SetObjectArrayElement(jarr, i, jnienv->NewStringUTF(pszWindowTitle));

	}

	return jarr;
}

/*
 * Class:     Win32PKDll
 * Method:    processes
 * Signature: ()[Ljava/lang/String;
 */
JNIEXPORT jobjectArray JNICALL Java_com_Prominic_jdi_system_Win32PKDll_processes
  (JNIEnv * jnienv, jobject)
{
	// paranoia ...
	if (jnienv == 0)
		return 0;

	// attempt to enum processes
    DWORD adwProcesses[2048], dwStored;
    if (!EnumProcesses(adwProcesses, sizeof(adwProcesses), &dwStored))
	{
		setException(jnienv, can_not_enumerate_processes, GetLastError(), __LINE__);
		return 0;
	}
	
	DWORD dwProcesses = dwStored / sizeof(DWORD);
	if (dwProcesses < 1)
	{
		setException(jnienv, internal_error, 0, __LINE__);
		return 0;
	}
	
	// create return array
	jobjectArray jarr = (jobjectArray) jnienv->NewObjectArray(
		dwProcesses, jnienv->FindClass("java/lang/String"),
		jnienv->NewStringUTF(""));

	if (jarr == 0)
	{
		setException(jnienv, can_not_create_array, 0, __LINE__);
		return 0;
	}

	char szProcessName[MAX_PATH];
	// store application names
	for (DWORD i = 0; i < dwProcesses; i++)
	{
		memset(szProcessName, 0, sizeof szProcessName);
		int nPos = 0;
		sprintf(szProcessName, "%d|%n", adwProcesses[i], &nPos);
		strcpy(szProcessName + nPos, "???");
		
		HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, 
			FALSE, adwProcesses[i]);

		if (hProcess)
		{
			HMODULE hMod;
			DWORD cbNeeded;
			
			if (EnumProcessModules(hProcess, &hMod, sizeof(hMod), 
				&cbNeeded))
				GetModuleBaseName(hProcess, hMod, szProcessName + nPos, sizeof(szProcessName) - nPos);
		}
		
		jnienv->SetObjectArrayElement(jarr, i, jnienv->NewStringUTF(szProcessName));
	}

	return jarr;
}

/*
 * Class:     Win32PKDll
 * Method:    app2pid
 * Signature: (Ljava/lang/String;)I
 */
JNIEXPORT jint JNICALL Java_com_Prominic_jdi_system_Win32PKDll_app2pid
  (JNIEnv * jnienv, jobject, jstring japp)
{
	//
	// check the parameters
	//
	
	// paranoia ...
	if ((jnienv == 0) || (japp == 0))
		return 0;
	
	const char * pszApp = jnienv->GetStringUTFChars(japp, 0);
	
	if (pszApp == 0)
	{
		setException(jnienv, param_errors, 0, __LINE__);
		return 0;
	}

	HWND hwnd = FindWindow(NULL, pszApp);
	if (hwnd == NULL)
	{
		setException(jnienv, no_window_for_app_name, GetLastError(), __LINE__);
		return 0;
	}

	DWORD dwPid = 0;
	DWORD dwThreadID = GetWindowThreadProcessId(hwnd, &dwPid);

	return dwPid;
}

/*
 * Class:     Win32PKDll
 * Method:    pid2exename
 * Signature: (I)Ljava/lang/String;
 */
JNIEXPORT jstring JNICALL Java_com_Prominic_jdi_system_Win32PKDll_pid2exename
  (JNIEnv * jnienv, jobject, jint jPID)
{
	//
	// check the parameters
	//
	
	// paranoia ...
	if (jnienv == 0)
		return 0;
	
	int nPID = (int)jPID;
	if (nPID < 0)
	{
		setException(jnienv, param_errors, 0, __LINE__);
		return 0;
	}
	
	DWORD dwPID = (DWORD)abs(nPID);

	char szProcessName[MAX_PATH];
	memset(szProcessName, 0, sizeof szProcessName);
	strcpy(szProcessName, "???");
		
	HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, 
			FALSE, dwPID);

	if (hProcess)
	{
		HMODULE hMod;
		DWORD cbNeeded;
		
		if (EnumProcessModules(hProcess, &hMod, sizeof(hMod), 
			&cbNeeded))
			GetModuleBaseName(hProcess, hMod, szProcessName, sizeof(szProcessName));
	}

	return jnienv->NewStringUTF(szProcessName);
}

/*
 * Class:     Win32PKDll
 * Method:    exist_pid
 * Signature: (I)Z
 */
JNIEXPORT jboolean JNICALL Java_com_Prominic_jdi_system_Win32PKDll_exist_1pid
  (JNIEnv * jnienv, jobject, jint jPID)
{
	//
	// check the parameters
	//
	
	// paranoia ...
	if (jnienv == 0)
		return jboolean(false);
	
	int nPID = (int)jPID;
	if (nPID < 0)
	{
		setException(jnienv, param_errors, 0, __LINE__);
		return jboolean(false);
	}
	
	DWORD dwPID = (DWORD)abs(nPID);

	jboolean jret = jboolean(false);
	// attempt to open process dwPid
	HANDLE hProcess = OpenProcess(PROCESS_TERMINATE, FALSE, dwPID);
	if (hProcess != NULL)
	{
		jret = jboolean(true);
		CloseHandle(hProcess);
	}
	
	return jret;
}

/*
 * Class:     Win32PKDll
 * Method:    get_tree
 * Signature: (I)[Ljava/lang/String;
 */
JNIEXPORT jintArray JNICALL Java_com_Prominic_jdi_system_Win32PKDll_get_1tree
  (JNIEnv * jnienv, jobject, jint jPID)
{
	//
	// check the parameters
	//
	
	// paranoia ...
	if (jnienv == 0)
		return 0;
	
	int nPID = (int)jPID;
	if (nPID < 0)
	{
		setException(jnienv, param_errors, 0, __LINE__);
		return 0;
	}
	
	DWORD dwPID = (DWORD)abs(nPID);

	CProcsSnapshot ps;
	
	// open snapshot
	if (!ps.StartSnapshot())
	{
		setException(jnienv, can_not_start_snapshot, 
			ps.getWin32Error(), __LINE__);
		return 0;
	}
	
	// allocate tree
	if (!ps.AllocTree(CProcsSnapshot::g_nMaxPIDs))
	{
		setException(jnienv, not_enough_memory, 0, __LINE__);
		return 0;
	}

	// attemp to walk first snapshot entry
	if (!ps.FirstSnapshotEntry())
	{
		// error
		setException(jnienv, can_not_iterate_snapshot, ps.getWin32Error(), __LINE__);
		return 0;
	}
	
	if (!ps.CreateTree())
	{
		setException(jnienv, can_not_iterate_snapshot, ps.getWin32Error(), __LINE__);
		return 0;
	}

	int nPIDs = ps.GetTreeLen(dwPID);

	jintArray jret = (jintArray) jnienv->NewIntArray(nPIDs);

	if (jret == 0)
	{
		setException(jnienv, can_not_create_array, 0, __LINE__);
		return 0;
	}

	ps.StoreTree(dwPID, jnienv, jret, 0);

	return jret;
}

/*
 * Class:     Win32PKDll
 * Method:    kill
 * Signature: (I)Z
 */
JNIEXPORT jboolean JNICALL Java_com_Prominic_jdi_system_Win32PKDll_kill
  (JNIEnv * jnienv, jobject, jint jPID)
{
	//
	// check the parameters
	//
	
	// paranoia ...
	if (jnienv == 0)
		return jboolean(false);
	
	int nPID = (int)jPID;
	if (nPID < 0)
	{
		setException(jnienv, param_errors, 0, __LINE__);
		return jboolean(false);
	}
	
	DWORD dwPID = (DWORD)abs(nPID);
	
	// attempt to open process dwPid
	HANDLE hProcess = OpenProcess(PROCESS_TERMINATE, FALSE, dwPID);
	if (hProcess == NULL)
	{
		setException(jnienv, can_not_open_process_for_pid, GetLastError(), __LINE__);
		return jboolean(false);
	}
	
	// attempt to terminate process
	UINT uExitCode = 0;
	bool bReturn = (TerminateProcess(hProcess, uExitCode) > 0);
	if (!bReturn)
	{
		setException(jnienv, can_not_kill, GetLastError(), __LINE__);
		return jboolean(false);
	}
	
	// clean up
	CloseHandle(hProcess);
	
	return jboolean(true);
}

/*
 * Class:     Win32PKDll
 * Method:    kill_tree
 * Signature: (I)[I
 */
JNIEXPORT jintArray JNICALL Java_com_Prominic_jdi_system_Win32PKDll_kill_1tree
  (JNIEnv * jnienv, jobject, jint jRootPid)
{
	// paranoia ...
	if (jnienv == 0)
		return 0;
	
	int nPID = (int)jRootPid;
	if (nPID < 0)
	{
		setException(jnienv, param_errors, 0, __LINE__);
		return 0;
	}
	
	DWORD dwPID = (DWORD)abs(nPID);
	
	CProcsSnapshot ps;
	
	// allocate tree
	if (!ps.AllocTree(CProcsSnapshot::g_nMaxPIDs))
	{
		setException(jnienv, not_enough_memory, 0, __LINE__);
		return 0;
	}

	// open snapshot
	if (!ps.StartSnapshot())
	{
		setException(jnienv, can_not_start_snapshot, 
			ps.getWin32Error(), __LINE__);
		return 0;
	}
	
	// attemp to walk first snapshot entry
	if (!ps.FirstSnapshotEntry())
	{
		// error
		setException(jnienv, can_not_iterate_snapshot, ps.getWin32Error(), __LINE__);
		return 0;
	}
	
	if (!ps.CreateTree())
	{
		setException(jnienv, can_not_iterate_snapshot, ps.getWin32Error(), __LINE__);
		return 0;
	}

	// create return array
	jintArray jarr = (jintArray) jnienv->NewIntArray(2);

	if (jarr == 0)
	{
		setException(jnienv, can_not_create_array, 0, __LINE__);
		return 0;
	}

	long nAll = 0, nKilled = 0;
	ps.KillTree(dwPID, nAll, nKilled);
	jnienv->SetIntArrayRegion(jarr, 0, 1, &nAll);
	jnienv->SetIntArrayRegion(jarr, 1, 1, &nKilled);

	return jarr;
}

//
// Helpers
//
enum service_errors
{
	ok2 = ok,
		can_not_open_scm,
		can_not_open_service,
		can_not_start_service,
		can_not_stop_service,
		can_not_query_service,
		can_not_create_array2,
		can_not_enumerate_services,
		can_not_query_lock_status
};

struct CServiceManag
{
	SC_HANDLE m_hSCM;
	DWORD m_dwWin32Error;

	SC_HANDLE m_hService;

	CServiceManag();
	~CServiceManag();
	DWORD getWin32Error(void) { return m_dwWin32Error; }

	bool OpenSCM(LPCTSTR lpMachineName, LPCTSTR lpDatabaseName, DWORD dwAccess);
	bool OpenService(LPCTSTR lpServiceName, DWORD dwDesiredAccess);
	bool GetServiceKeyName(LPCTSTR lpDisplayName, LPTSTR lpServiceName, LPDWORD lpcchBuffer);
	bool GetServiceDisplayName(LPCTSTR lpServiceName, LPTSTR lpDisplayName,  LPDWORD lpcchBuffer);
};

CServiceManag::CServiceManag()
{
	m_hSCM = NULL;
	m_hService = NULL;
	m_dwWin32Error = 0;
}

CServiceManag::~CServiceManag()
{
	if (m_hService != NULL)
		CloseServiceHandle(m_hService);
	m_hService = NULL;

	if (m_hSCM != NULL)
		CloseServiceHandle(m_hSCM);
	m_hSCM = NULL;
}

bool CServiceManag::OpenSCM(LPCTSTR lpMachineName, LPCTSTR lpDatabaseName, DWORD dwAccess)
{
	m_hSCM = OpenSCManager(lpMachineName, lpDatabaseName, dwAccess);
	if (m_hSCM == NULL)
	{
		m_dwWin32Error = GetLastError();
		return false;
	}

	return true;
}

bool CServiceManag::OpenService(LPCTSTR lpServiceName, DWORD dwDesiredAccess)
{
	if (m_hSCM == NULL)
		return false;

	m_hService = ::OpenService(m_hSCM, lpServiceName, dwDesiredAccess);
	if (m_hService == NULL)
	{
		m_dwWin32Error = GetLastError();
		return false;
	}

	return true;
}

bool CServiceManag::GetServiceKeyName(LPCTSTR lpDisplayName, LPTSTR lpServiceName, LPDWORD lpcchBuffer)
{
	if (m_hSCM == NULL)
		return false;

	BOOL bGet = ::GetServiceKeyName(m_hSCM, lpDisplayName, lpServiceName, lpcchBuffer);
	if (!bGet)
		m_dwWin32Error = GetLastError();

	return (bGet > 0);
}

bool CServiceManag::GetServiceDisplayName(LPCTSTR lpServiceName, LPTSTR lpDisplayName,  LPDWORD lpcchBuffer)
{
	if (m_hSCM == NULL)
		return false;

	BOOL bGet = ::GetServiceDisplayName(m_hSCM, lpServiceName, lpDisplayName, lpcchBuffer);
	if (!bGet)
		m_dwWin32Error = GetLastError();

	return (bGet > 0);
}


/*
 * Class:     Win32PKDll
 * Method:    startService
 * Signature: (Ljava/lang/String;)Z
 */
JNIEXPORT jboolean JNICALL Java_com_Prominic_jdi_system_Win32PKDll_startService
  (JNIEnv * jnienv, jobject, jstring jservicename)
{
	//
	// check the parameters
	//
	
	// paranoia ...
	if ((jnienv == 0) || (jservicename == 0))
		return 0;
	
	CServiceManag scm;
	if (!scm.OpenSCM(NULL, NULL, SC_MANAGER_CONNECT))
	{
		setException(jnienv, can_not_open_scm, scm.getWin32Error(), __LINE__);
		return jboolean(false);
	}
	
	const char * pszServiceName = jnienv->GetStringUTFChars(jservicename, 0);
	if (!scm.OpenService(pszServiceName, SERVICE_START))
	{
		setException(jnienv, can_not_open_service, scm.getWin32Error(), __LINE__);
		return jboolean(false);
	}

	// service succesfully opened
	BOOL bStarted = StartService(scm.m_hService, 0, 0);
	if (!bStarted)
	{
		setException(jnienv, can_not_start_service, GetLastError(), __LINE__);
		return jboolean(false);
	}

	return jboolean(true);
}

/*
 * Class:     Win32PKDll
 * Method:    stopService
 * Signature: (Ljava/lang/String;)Z
 */
JNIEXPORT jboolean JNICALL Java_com_Prominic_jdi_system_Win32PKDll_stopService
  (JNIEnv * jnienv, jobject, jstring jservicename)
{
	//
	// check the parameters
	//
	
	// paranoia ...
	if ((jnienv == 0) || (jservicename == 0))
		return 0;
	
	CServiceManag scm;
	if (!scm.OpenSCM(NULL, NULL, SC_MANAGER_CONNECT))
	{
		setException(jnienv, can_not_open_scm, scm.getWin32Error(), __LINE__);
		return jboolean(false);
	}
	
	const char * pszServiceName = jnienv->GetStringUTFChars(jservicename, 0);
	if (!scm.OpenService(pszServiceName, SERVICE_STOP))
	{
		setException(jnienv, can_not_open_service, scm.getWin32Error(), __LINE__);
		return jboolean(false);
	}

	// service succesfully opened
	SERVICE_STATUS status;
	memset(&status, 0, sizeof status);
	BOOL bStopped = ControlService(scm.m_hService, SERVICE_CONTROL_STOP, &status);
	if (!bStopped)
	{
		setException(jnienv, can_not_stop_service, GetLastError(), __LINE__);
		return jboolean(false);
	}

	return jboolean(true);
}

/*
 * Class:     Win32PKDll
 * Method:    isRunningService
 * Signature: (Ljava/lang/String;)Z
 */
JNIEXPORT jboolean JNICALL Java_com_Prominic_jdi_system_Win32PKDll_isRunningService
  (JNIEnv * jnienv, jobject, jstring jservicename)
{
	//
	// check the parameters
	//
	
	// paranoia ...
	if ((jnienv == 0) || (jservicename == 0))
		return 0;
	
	CServiceManag scm;
	if (!scm.OpenSCM(NULL, NULL, SC_MANAGER_CONNECT))
	{
		setException(jnienv, can_not_open_scm, scm.getWin32Error(), __LINE__);
		return jboolean(false);
	}
	
	const char * pszServiceName = jnienv->GetStringUTFChars(jservicename, 0);
	if (!scm.OpenService(pszServiceName, SERVICE_QUERY_STATUS))
	{
		setException(jnienv, can_not_open_service, scm.getWin32Error(), __LINE__);
		return jboolean(false);
	}

	// service succesfully opened

	SERVICE_STATUS status;
	if (!QueryServiceStatus(scm.m_hService, &status))
	{
		setException(jnienv, can_not_query_service, scm.getWin32Error(), __LINE__);
		return jboolean(false);
	}

	return jboolean(status.dwCurrentState == SERVICE_RUNNING);
}

/*
 * Class:     Win32PKDll
 * Method:    isConfiguredService
 * Signature: (Ljava/lang/String;)Z
 */
JNIEXPORT jboolean JNICALL Java_com_Prominic_jdi_system_Win32PKDll_isConfiguredService
  (JNIEnv * jnienv, jobject, jstring jservicename)
{
	//
	// check the parameters
	//
	
	// paranoia ...
	if ((jnienv == 0) || (jservicename == 0))
		return 0;
	
	CServiceManag scm;
	if (!scm.OpenSCM(NULL, NULL, SC_MANAGER_CONNECT))
	{
		setException(jnienv, can_not_open_scm, scm.getWin32Error(), __LINE__);
		return jboolean(false);
	}
	
	const char * pszServiceName = jnienv->GetStringUTFChars(jservicename, 0);
	if (!scm.OpenService(pszServiceName, SERVICE_QUERY_STATUS))
	{
		if (scm.getWin32Error() != ERROR_SERVICE_DOES_NOT_EXIST)
			setException(jnienv, can_not_open_service, scm.getWin32Error(), __LINE__);
		return jboolean(false);
	}

	// service succesfully opened
	// then it is configured
	return jboolean(true);
}

/*
 * Class:     Win32PKDll
 * Method:    listServices
 * Signature: ()[Ljava/lang/String;
 */
JNIEXPORT jobjectArray JNICALL Java_com_Prominic_jdi_system_Win32PKDll_listServices
  (JNIEnv * jnienv, jobject)
{
	//
	// check the parameters
	//
	
	// paranoia ...
	if (jnienv == 0)
		return 0;
	
	CServiceManag scm;
	if (!scm.OpenSCM(NULL, NULL, SC_MANAGER_ENUMERATE_SERVICE))
	{
		setException(jnienv, can_not_open_scm, scm.getWin32Error(), __LINE__);
		return 0;
	}

	DWORD dwBytesNeeded = 0;
	DWORD dwServicesReturned = 0;
	DWORD dwResumeHandle = 0;
	BOOL bEnum = EnumServicesStatus(scm.m_hSCM, SERVICE_WIN32, SERVICE_STATE_ALL, 
		0, 0, &dwBytesNeeded, &dwServicesReturned, &dwResumeHandle);
	
	DWORD dwError = GetLastError();
	if (!bEnum && (dwError == ERROR_MORE_DATA))
	{
		// succefully determined the size of the buffer 
		// to retrieve the services information

		// allocate the buffer
		char * pcStatus = new char [dwBytesNeeded];
		LPENUM_SERVICE_STATUS pStatus = (LPENUM_SERVICE_STATUS) pcStatus;
		memset(pStatus, 0, dwBytesNeeded);
		bEnum = EnumServicesStatus(scm.m_hSCM, SERVICE_WIN32, SERVICE_STATE_ALL, 
			pStatus, dwBytesNeeded, &dwBytesNeeded, &dwServicesReturned, &dwResumeHandle);
		
		// create return array
		jobjectArray jarr = (jobjectArray) jnienv->NewObjectArray(
			dwServicesReturned, jnienv->FindClass("java/lang/String"),
			jnienv->NewStringUTF(""));
		
		if (jarr == 0)
		{
			delete [] pcStatus;
			setException(jnienv, can_not_create_array, 0, __LINE__);
			return 0;
		}
		
		for (int i = 0; i < dwServicesReturned; i++)
			jnienv->SetObjectArrayElement(jarr, i, jnienv->NewStringUTF(pStatus[i].lpServiceName));

		delete [] pcStatus;
		
		return jarr;
	}
	else
	{
		// same error happened
		setException(jnienv, can_not_enumerate_services, dwError, __LINE__);
		return 0;
	}

	return 0;
}

/*
 * Class:     Win32PKDll
 * Method:    isServiceDBLocked
 * Signature: ()Z
 */
JNIEXPORT jboolean JNICALL Java_com_Prominic_jdi_system_Win32PKDll_isServiceDBLocked
  (JNIEnv * jnienv, jobject)
{
	//
	// check the parameters
	//
	
	// paranoia ...
	if (jnienv == 0)
		return 0;
	
	CServiceManag scm;
	if (!scm.OpenSCM(NULL, NULL, SC_MANAGER_QUERY_LOCK_STATUS))
	{
		setException(jnienv, can_not_open_scm, scm.getWin32Error(), __LINE__);
		return jboolean(false);
	}

	DWORD dwBytesNeeded = 0;
	BOOL bGetLock = QueryServiceLockStatus(scm.m_hSCM, 0, 0, &dwBytesNeeded);
	DWORD dwError = GetLastError();
	if (!bGetLock && (dwError != ERROR_INSUFFICIENT_BUFFER))
	{
		// other error
		setException(jnienv, can_not_query_lock_status, scm.getWin32Error(), __LINE__);
		return jboolean(false);
	}

	LPQUERY_SERVICE_LOCK_STATUS pStatus;
	char * pcStatus = new char [dwBytesNeeded];
	pStatus = (LPQUERY_SERVICE_LOCK_STATUS) pcStatus;
	memset(pStatus, 0, dwBytesNeeded);
	DWORD dwBytesNeeded2 = 0;
	bGetLock = QueryServiceLockStatus(scm.m_hSCM, pStatus, dwBytesNeeded, &dwBytesNeeded2);
	dwError = GetLastError();
	bool bLocked = pStatus->fIsLocked > 0;
	delete [] pcStatus;

	// succefully
	return jboolean(bLocked);
}

/*
 * Class:     Win32PKDll
 * Method:    service2pid
 * Signature: (Ljava/lang/String;)I
 */
JNIEXPORT jint JNICALL Java_com_Prominic_jdi_system_Win32PKDll_service2pid
  (JNIEnv * jnienv, jobject, jstring jservicename)
{
	//
	// check the parameters
	//
	
	// paranoia ...
	if ((jnienv == 0) || (jservicename == 0))
		return -1;
	
	CServiceManag scm;
	if (!scm.OpenSCM(NULL, NULL, SC_MANAGER_CONNECT))
	{
		setException(jnienv, can_not_open_scm, scm.getWin32Error(), __LINE__);
		return -1;
	}
	
	const char * pszServiceName = jnienv->GetStringUTFChars(jservicename, 0);
	if (!scm.OpenService(pszServiceName, SERVICE_QUERY_STATUS))
	{
		setException(jnienv, can_not_open_service, scm.getWin32Error(), __LINE__);
		return -1;
	}

	// service succesfully opened

	SERVICE_STATUS_PROCESS status;
	DWORD dwLen = 0;
	if (!QueryServiceStatusEx(scm.m_hService, SC_STATUS_PROCESS_INFO,
		(LPBYTE)&status, sizeof status, &dwLen))
	{
		setException(jnienv, can_not_query_service, scm.getWin32Error(), __LINE__);
		return -1;
	}

	return (status.dwProcessId == 0) ? -1 : status.dwProcessId;
}

/*
 * Class:     Win32PKDll
 * Method:    getServiceState
 * Signature: (Ljava/lang/String;)I
 */
JNIEXPORT jint JNICALL Java_com_Prominic_jdi_system_Win32PKDll_getServiceState
  (JNIEnv * jnienv, jobject, jstring jservicename)
{
	bool bUpdate = true;
	//
	// check the parameters
	//
	
	// paranoia ...
	if ((jnienv == 0) || (jservicename == 0))
		return 0;
	
	CServiceManag scm;
	if (!scm.OpenSCM(NULL, NULL, SC_MANAGER_CONNECT))
	{
		setException(jnienv, can_not_open_scm, scm.getWin32Error(), __LINE__);
		return -1;
	}
	
	const char * pszServiceName = jnienv->GetStringUTFChars(jservicename, 0);
	if (!scm.OpenService(pszServiceName, 
		bUpdate ? SERVICE_INTERROGATE : SERVICE_QUERY_STATUS))
	{
		setException(jnienv, can_not_open_service, GetLastError(), __LINE__);
		return -1;
	}

	// service succesfully opened

	SERVICE_STATUS status;

	if (bUpdate)
	{
		if (!ControlService(scm.m_hService, SERVICE_CONTROL_INTERROGATE, &status))
		{
			DWORD dwError = GetLastError();
			if (dwError == ERROR_SERVICE_REQUEST_TIMEOUT)
				return -1;
			else
			{
				setException(jnienv, can_not_query_service, GetLastError(), __LINE__);
				return -1;
			}
		}
	}
	else
	{
		if (!QueryServiceStatus(scm.m_hService, &status))
		{
			setException(jnienv, can_not_query_service, GetLastError(), __LINE__);
			return -1;
		}
	}

	return status.dwCurrentState;
}

/*
 * Class:     Win32PKDll
 * Method:    getServiceControls
 * Signature: ()I
 */
JNIEXPORT jint JNICALL Java_com_Prominic_jdi_system_Win32PKDll_getServiceControls
  (JNIEnv * jnienv, jobject, jstring jservicename)
{
	//
	// check the parameters
	//
	
	// paranoia ...
	if ((jnienv == 0) || (jservicename == 0))
		return 0;
	
	CServiceManag scm;
	if (!scm.OpenSCM(NULL, NULL, SC_MANAGER_CONNECT))
	{
		setException(jnienv, can_not_open_scm, scm.getWin32Error(), __LINE__);
		return jboolean(false);
	}
	
	const char * pszServiceName = jnienv->GetStringUTFChars(jservicename, 0);
	if (!scm.OpenService(pszServiceName, SERVICE_QUERY_STATUS))
	{
		setException(jnienv, can_not_open_service, scm.getWin32Error(), __LINE__);
		return jboolean(false);
	}

	// service succesfully opened

	SERVICE_STATUS status;
	if (!QueryServiceStatus(scm.m_hService, &status))
	{
		setException(jnienv, can_not_query_service, scm.getWin32Error(), __LINE__);
		return jboolean(false);
	}

	return jboolean(status.dwControlsAccepted);
}

/*
 * Class:     Win32PKDll
 * Method:    displayName2ServiceName
 * Signature: (Ljava/lang/String;)Ljava/lang/String;
 */
JNIEXPORT jstring JNICALL Java_com_Prominic_jdi_system_Win32PKDll_displayName2ServiceName
  (JNIEnv * jnienv, jobject, jstring jdisplayname)
{
	//
	// check the parameters
	//
	
	// paranoia ...
	if ((jnienv == 0) || (jdisplayname == 0))
		return 0;
	
	CServiceManag scm;
	if (!scm.OpenSCM(NULL, NULL, SC_MANAGER_CONNECT))
	{
		setException(jnienv, can_not_open_scm, scm.getWin32Error(), __LINE__);
		return 0;
	}
	
	const char * pszDisplayName = jnienv->GetStringUTFChars(jdisplayname, 0);
	char szKeyName[MAX_PATH];
	DWORD dwLen = sizeof szKeyName;
	if (!scm.GetServiceKeyName(pszDisplayName, szKeyName, &dwLen))
	{
		setException(jnienv, can_not_open_scm, scm.getWin32Error(), __LINE__);
		return 0;
	}

	return jnienv->NewStringUTF(szKeyName);
}

/*
 * Class:     Win32PKDll
 * Method:    serviceName2DisplayName
 * Signature: (Ljava/lang/String;)Ljava/lang/String;
 */
JNIEXPORT jstring JNICALL Java_com_Prominic_jdi_system_Win32PKDll_serviceName2DisplayName
  (JNIEnv * jnienv, jobject, jstring jkeyname)
{
	//
	// check the parameters
	//
	
	// paranoia ...
	if ((jnienv == 0) || (jkeyname == 0))
		return 0;
	
	CServiceManag scm;
	if (!scm.OpenSCM(NULL, NULL, SC_MANAGER_CONNECT))
	{
		setException(jnienv, can_not_open_scm, scm.getWin32Error(), __LINE__);
		return 0;
	}
	
	const char * pszKeyName = jnienv->GetStringUTFChars(jkeyname, 0);
	char szDisplayName[MAX_PATH];
	DWORD dwLen = sizeof szDisplayName;
	if (!scm.GetServiceDisplayName(pszKeyName, szDisplayName, &dwLen))
	{
		setException(jnienv, can_not_open_scm, scm.getWin32Error(), __LINE__);
		return 0;
	}

	return jnienv->NewStringUTF(szDisplayName);
}

enum access_control_errors
{
	ok3 = ok,
		can_not_open_process_token,
		can_not_lookup_privilege,
		can_not_check_privilege,
		can_not_adjust_privilege
		
};

/*
 * Class:     Win32PKDll
 * Method:    isDebugPrivilegeEnabled
 * Signature: ()Z
 */
JNIEXPORT jboolean JNICALL Java_com_Prominic_jdi_system_Win32PKDll_isDebugPrivilegeEnabled
  (JNIEnv * jnienv, jobject)
{
	//
	// check the parameters
	//
	
	// paranoia ...
	if (jnienv == 0)
		return 0;

	HANDLE hProcessToken;
	if (!OpenProcessToken(GetCurrentProcess(), 
		TOKEN_QUERY,
		&hProcessToken))
	{
		setException(jnienv, can_not_open_process_token, GetLastError(), __LINE__);
		return jboolean(false);
	}

	LUID luidPriv;
	if (!LookupPrivilegeValue(NULL, SE_DEBUG_NAME, &luidPriv))
	{
		setException(jnienv, can_not_lookup_privilege, GetLastError(), __LINE__);
		return jboolean(false);
	}

	PRIVILEGE_SET privset;
	privset.PrivilegeCount = 1;
	privset.Control = 0;
	privset.Privilege[0].Luid = luidPriv;
	privset.Privilege[0].Attributes = 0;

	BOOL bSet = FALSE;
	if (!PrivilegeCheck(hProcessToken, &privset, &bSet))
	{
		setException(jnienv, can_not_check_privilege, GetLastError(), __LINE__);
		return jboolean(false);
	}

	return jboolean(privset.Privilege[0].Attributes == 
		SE_PRIVILEGE_USED_FOR_ACCESS);
}

/*
 * Class:     Win32PKDll
 * Method:    enableDebugPrivilege
 * Signature: (Z)V
 */
JNIEXPORT void JNICALL Java_com_Prominic_jdi_system_Win32PKDll_enableDebugPrivilege
  (JNIEnv * jnienv, jobject, jboolean jEnable)
{
	//
	// check the parameters
	//
	
	// paranoia ...
	if (jnienv == 0)
		return;

	HANDLE hProcessToken;
	if (!OpenProcessToken(GetCurrentProcess(), 
		TOKEN_ADJUST_PRIVILEGES,
		&hProcessToken))
	{
		setException(jnienv, can_not_open_process_token, GetLastError(), __LINE__);
		return;
	}

	LUID luidPriv;
	if (!LookupPrivilegeValue(NULL, SE_DEBUG_NAME, &luidPriv))
	{
		setException(jnienv, can_not_lookup_privilege, GetLastError(), __LINE__);
		return;
	}

	TOKEN_PRIVILEGES tokprivsCrt;
	tokprivsCrt.PrivilegeCount = 1;
	tokprivsCrt.Privileges[0].Luid = luidPriv;
	tokprivsCrt.Privileges[0].Attributes = jEnable ? SE_PRIVILEGE_ENABLED : 0;

	if (!AdjustTokenPrivileges(hProcessToken, FALSE,
		&tokprivsCrt, 0, NULL, NULL))
	{
		setException(jnienv, can_not_adjust_privilege, GetLastError(), __LINE__);
		return;
	}
}

