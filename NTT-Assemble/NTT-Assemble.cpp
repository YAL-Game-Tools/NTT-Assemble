#include "stdafx.h"
#include <stdlib.h>
#include <conio.h>
#include <string.h>
#include <ctime>
#define fquit(...) { printf(__VA_ARGS__); printf("\n"); fflush(stdout); quit(); }
//
void quit(int status = 1) {
	_getch();
	exit(status);
}
/// reads n bytes from f1 and writes them to f2
void fcopy(FILE* f1, FILE* f2, int n) {
	char buf[BUFSIZ];
	while (n > 0) {
		int i = BUFSIZ;
		if (i > n) i = n;
		int q = fread(buf, 1, i, f1);
		fwrite(buf, 1, q, f2);
		n -= i;
	}
}
/// copies file contents from the current position to eof
void fcopy_all(FILE* f1, FILE* f2) {
	char buf[BUFSIZ];
	size_t size;
	while (size = fread(buf, 1, BUFSIZ, f1)) {
		fwrite(buf, 1, size, f2);
	}
}
/// writes n zeroes to f.
void fwrite_z(FILE* f, int n) {
	char buf[BUFSIZ];
	memset(buf, 0, BUFSIZ);
	while (n > 0) {
		int i = BUFSIZ;
		if (i > n) i = n;
		fwrite(buf, 1, i, f);
		n -= i;
	}
}
const unsigned int CH_FORM = 0x4d524f46;
const unsigned int CH_GEN8 = 0x384e4547;
const unsigned int CH_AUDO = 0x4f445541;
long dataStart;
unsigned int dataSize;
FILE* seek_chunk(char* path, unsigned int chunk) {
	FILE* f = fopen(path, "rb");
	if (!f) fquit("Couldn't open file `%s`. Did you follow the instructions?", path);
	printf("Looking for data chunk in `%s`...\n", path);
	// seek 'FORM'[size]'GEN8':
	bool dataFound = false;
	while (!feof(f)) {
		unsigned int next;
		if (!fread(&next, 4, 1, f)) break;
		if (next != CH_FORM) continue;
		if (!fread(&dataSize, 4, 1, f)) break;
		dataStart = ftell(f);
		if (!fread(&next, 4, 1, f)) break;
		if (next != CH_GEN8) continue;
		if (!fread(&next, 4, 1, f)) break;
		fseek(f, next, SEEK_CUR); // skip GEN8
		dataFound = true;
		break;
	}
	if (!dataFound) {
		fclose(f);
		fquit("Couldn't find data chunk in `%s`.\n", path);
	}
	if (chunk == CH_FORM) {
		fseek(f, dataStart, SEEK_SET);
		return f;
	}
	// seek the according chunk if specified:
	long dataEnd = dataStart + dataSize;
	while (!feof(f) && ftell(f) < dataEnd) {
		unsigned int next;
		if (!fread(&next, 4, 1, f)) break;
		if (next != chunk) {
			if (!fread(&next, 4, 1, f)) break;
			if (next < 0) break;
			fseek(f, next, SEEK_CUR);
			continue;
		}
		return f;
	}
	printf("Couldn't find data chunk in `%s`.\n", path);
	fclose(f);
	quit();
	return NULL;
}
/// Realigns and copies asset list header between files.
void fcopy_assets(FILE* f1, FILE* f2, long s1, long s2) {
	long d = (ftell(f2) - s2) - (ftell(f1) - s1);
	unsigned int count;
	fread(&count, 4, 1, f1);
	fwrite(&count, 4, 1, f2);
	for (unsigned int i = 0; i < count; i++) {
		unsigned int addr;
		fread(&addr, 4, 1, f1);
		addr += d;
		fwrite(&addr, 4, 1, f2);
	}
}
FILE* fopen_wrap(char* path, int mode) {
	FILE* r = fopen(path, mode ? "wb" : "rb");
	if (r == 0) {
		if (mode) {
			fquit("Couldn't open `%s` for writing. Is it open in another application?", path);
		} else fquit("Couldn't open `%s` for reading. Is the file in place?", path);
	}
	return r;
}
char* path_exe = "nuclearthrone.exe";
char* path_p1 = "nuclearthrone-1.part";
char* path_p2 = "nuclearthrone-2.part";
char* path_win = "data.win";
char path_bck[64] = "nuclearthrone-original (YYYY-MM-DD hh-mm-ss).exe";
/// Updates path_bck. There was a library function for this too.
void path_bck_proc() {
	int i = 23;
	time_t now_t = time(0);
	struct tm * now = localtime(&now_t);
	int year = now->tm_year + 1900;
	path_bck[++i] = '0' + (year / 1000) % 10;
	path_bck[++i] = '0' + (year / 100) % 10;
	path_bck[++i] = '0' + (year / 10) % 10;
	path_bck[++i] = '0' + year % 10;
	i++;
	path_bck[++i] = '0' + ((now->tm_mon + 1) / 10);
	path_bck[++i] = '0' + ((now->tm_mon + 1) % 10);
	i++;
	path_bck[++i] = '0' + (now->tm_mday / 10);
	path_bck[++i] = '0' + (now->tm_mday % 10);
	i++;
	path_bck[++i] = '0' + (now->tm_hour / 10);
	path_bck[++i] = '0' + (now->tm_hour % 10);
	i++;
	path_bck[++i] = '0' + (now->tm_min / 10);
	path_bck[++i] = '0' + (now->tm_min % 10);
	i++;
	path_bck[++i] = '0' + (now->tm_sec / 10);
	path_bck[++i] = '0' + (now->tm_sec % 10);
}
/// splits a preprocessed executable into .part files
int main_preproc() {
	FILE* exe = seek_chunk(path_exe, CH_AUDO);
	unsigned int aus; fread(&aus, 4, 1, exe);
	long aup = ftell(exe);
	// p1:
	FILE* rp1 = fopen_wrap(path_p1, 1);
	fseek(exe, 0, SEEK_SET);
	fcopy(exe, rp1, aup);
	fclose(rp1);
	// p2:
	FILE* rp2 = fopen_wrap(path_p2, 1);
	fseek(exe, aup + aus, SEEK_SET);
	fcopy_all(exe, rp2);
	fclose(rp2);
	//
	fclose(exe);
	return 0;
}
int main_export(int argc, char** argv) {
	if (argc < 4) fquit("Usage: -export [executable path] [data.win path]");
	printf("Exporting data from `%s` to `%s`...\n", argv[2], argv[3]);
	FILE* exe = seek_chunk(argv[2], CH_FORM);
	FILE* win = fopen_wrap(argv[3], 1);
	printf("Copying data...\n");
	fseek(exe, -8, SEEK_CUR);
	fcopy(exe, win, dataSize + 8);
	fclose(exe);
	fclose(win);
	printf("All done!");
}
int main_import(int argc, char** argv) {
	if (argc < 5) fquit("Usage: -import [executable path] [data.win path] [output path]");
	printf("Combining `%s` with datafile `%s` into `%s`...\n", argv[2], argv[3], argv[4]);
	FILE* src = seek_chunk(argv[2], CH_FORM);
	long srcStart = dataStart;
	unsigned int srcSize = dataSize;
	FILE* win = seek_chunk(argv[3], CH_FORM);
	if (srcSize != dataSize) fquit("Datafile size and executable size must match (%u != %u)", dataSize, srcSize);
	FILE* dst = fopen_wrap(argv[4], 1);
	printf("Copying header...\n");
	fseek(src, 0, SEEK_SET);
	fcopy(src, dst, srcStart);
	printf("Copying data...\n");
	fcopy(win, dst, dataSize);
	fseek(src, srcSize, SEEK_CUR);
	printf("Copying trail...\n");
	fcopy_all(src, dst);
	fclose(src);
	fclose(win);
	fclose(dst);
	printf("All done!");
}
int main_assemble(bool backup) {
	FILE* exe;
	//
	printf("Making a backup of the original executable...\n");
	if (backup) {
		exe = fopen(path_exe, "rb");
		if (exe) {
			path_bck_proc();
			FILE* bck = fopen_wrap(path_bck, 1);
			fcopy_all(exe, bck);
			fclose(exe);
			fclose(bck);
		} else printf("Original executable is not there..?\n");
	}
	//
	printf("Reassembling Nuclear Throne Together...\n");
	//
	FILE* rp1 = seek_chunk(path_p1, CH_AUDO);
	long rawStart = dataStart;
	unsigned int rawLen; fread(&rawLen, 4, 1, rp1);
	long rawPos = ftell(rp1);
	//
	FILE* rp2 = fopen_wrap(path_p2, 0);
	//
	FILE* win = seek_chunk(path_win, CH_AUDO);
	long winStart = dataStart;
	unsigned int winLen; fread(&winLen, 4, 1, win);
	long winPos = ftell(win);
	//
	exe = fopen(path_exe, "wb");
	if (!exe) fquit("Couldn't open `%s` for writing.\nMake sure that the game is not running.\n", path_exe);
	// copy p1 (start..audio start):
	fseek(rp1, 0, SEEK_SET);
	fcopy(rp1, exe, rawPos);
	fclose(rp1);
	// copy audio from data.win:
	fcopy_assets(win, exe, winStart, rawStart);
	fcopy(win, exe, winPos + winLen - ftell(win));
	fclose(win);
	// padding:
	fwrite_z(exe, rawLen - winLen);
	// copy p2 (trail):
	fcopy_all(rp2, exe);
	fclose(rp2);
	//
	fclose(exe);
	if (backup) {
		printf("All done! Press any key to exit.\n");
		quit(0);
	} // no need to require a key press if ran with parameters
	return 0;
}
int main(int argc, char** argv) {
	if (argc > 1) {
		char* par = argv[1];
		// launched with parameters
		if (strcmp(par, "-preproc") == 0) return main_preproc();
		if (strcmp(par, "-export") == 0) return main_export(argc, argv);
		if (strcmp(par, "-import") == 0) return main_import(argc, argv);
		if (strcmp(par, "-nobackup") == 0) return main_assemble(false);
		fquit("`%s` is not a known parameter.", par);
		return 0;
	} else return main_assemble(true);
}

