/**
 * 画像を中央に設置する
*/
void image_fit_center();

/**
 * キーを押下した
*/
void on_key_press(int key, int mods);

/**
 * キーを離した
*/
void on_key_release(int key, int mods);

/**
 * キー押しっぱ
*/
void on_key_pressing(int key, int mods);

/**
 * マウスクリック
*/
void on_mouse_click(int button);

/**
 * マウスクリック終わった
*/
void on_mouse_release(int button);

/**
 * マウス移動
*/
void on_mouse_move(double x, double y);

/**
 * スクロール
*/
void on_mouse_scroll(double delta_x, double delta_y);

/**
 * ウィンドウリサイズ
*/
void on_window_resize(uint32_t width, uint32_t height);

/**
 * ドラドロ
*/
void on_dd(int count, const char **pathlp);

/**
 * メインループ
*/
void main_loop();