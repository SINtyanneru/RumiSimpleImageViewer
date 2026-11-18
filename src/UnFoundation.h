//Foundation の代わりをする最小ライブラリの公開 API（C言語）
//Linux / macOS では UnFoundation.m が本物の Foundation を包み、
//それ以外（Windows・BSD 等）では UnFoundation.c が C 標準ライブラリで実装する。
//アプリ側はどちらの環境でもこの C の API だけを使い、ObjC の型は持ち込まない
//（＝ Linux / macOS 以外では ObjC ランタイムを一切通らない）。

//C として読まれたとき用の BOOL（ObjC のときは objc の定義がある）
#if !defined(__OBJC__) && !defined(_WINDEF_)
typedef unsigned char BOOL;
#define YES 1
#define NO 0
#endif

//文字列リスト（文字列はコピーして持つ）
typedef struct UnStringList UnStringList;

UnStringList *un_list_create(void);
void un_list_add(UnStringList *list, const char *text);
int un_list_count(UnStringList *list);
const char *un_list_get(UnStringList *list, int index);
void un_list_clear(UnStringList *list);

//プログラム引数（UTF-8 の C 文字列として返す。0番はプログラム名）
int un_arg_count(void);
const char *un_arg_get(int index);

//main() の引数の受け口（UnFoundation.c 用。UnFoundation.m は NSProcessInfo を使うので未使用）
extern int rsiv_argc;
extern char **rsiv_argv;
