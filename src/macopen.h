#import "rsiv.h"

//macOS で Finder の関連付けから開かれたときの受け口を登録する
//（ファイルパスは argv ではなく Apple Event で届く）
void rsiv_mac_install_open_handler(SharedImage *shared_image);
