/**
 * Claude作
*/
#import <stdint.h>
#import "rsiv.h"
#import <math.h>

//FuBK テストパターン(4:3 / 625本PAL用)
//RGBAとImageは既存の定義を使う
//
//座標は格子1マス(ピッチ)を単位にする。画像中心が原点、右がu、下がv
//  格子 : 縦19本(u=-9..9) x 横15本(v=-7..7)、25%グレー地に白線
//  円   : 半径sqrt(45)マス(格子の交点8か所を通る)
//  中央 : 幅12 x 高さ10マスの矩形領域にテスト信号を並べる(円ではクリップしない)
//  上から カラーバー(3マス) / グレースケール(2マス) / 黒区間(1マス)
//         / グレーティング(1マス) / 三角(1マス) / ランプと反PAL(2マス)

//4.433MHzを橙色パッチで描くか(1:実機の見た目 / 0:実際に縞を描く)
#ifndef FUBK_4433_AS_ORANGE
#define FUBK_4433_AS_ORANGE 1
#endif

//カラーバーの白レベル(0.75:75/0/75/0 / 1.0:100/0/75/0)
#ifndef FUBK_BAR_LEVEL
#define FUBK_BAR_LEVEL 0.75
#endif

//黒区間の文字(十字の左と右。各2文字まで)
#ifndef FUBK_TEXT_LEFT
#define FUBK_TEXT_LEFT "RS"
#endif
#ifndef FUBK_TEXT_RIGHT
#define FUBK_TEXT_RIGHT "IV"
#endif

//格子1マスの時間(マイクロ秒)。48サンプル / 17.734475MHz
#define FUBK_CELL_US (48.0 / 17.734475)

static RGBA fubk_rgb(double r, double g, double b) {
    RGBA c;
    c.r = (uint8_t)(r * 255.0 + 0.5);
    c.g = (uint8_t)(g * 255.0 + 0.5);
    c.b = (uint8_t)(b * 255.0 + 0.5);
    c.a = 255;
    return c;
}

static RGBA fubk_gray(double l) {
    return fubk_rgb(l, l, l);
}

//縞(正弦波)。cyclesは1マスあたりの周期数ではなく、開始位置からの累積周期
static RGBA fubk_grating(double du, double mhz) {
    double cycles = du * mhz * FUBK_CELL_US;
    return fubk_gray(0.5 + 0.5 * sin(2.0 * M_PI * cycles));
}

//5x7ビットマップフォント(必要な文字だけ。増やすときはここに足す)
static const uint8_t *fubk_glyph(char ch) {
    static const uint8_t R[7] = {0x1E, 0x11, 0x11, 0x1E, 0x14, 0x12, 0x11};
    static const uint8_t S[7] = {0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E};
    static const uint8_t I[7] = {0x0E, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0E};
    static const uint8_t V[7] = {0x11, 0x11, 0x11, 0x11, 0x11, 0x0A, 0x04};
    switch (ch) {
        case 'R': return R;
        case 'S': return S;
        case 'I': return I;
        case 'V': return V;
        default:  return 0;
    }
}

//文字列の(u,v)が文字の点にあたるか。(ux,vy)は左上、dは1ドットの大きさ(マス)
static int fubk_text(const char *s, double u, double v, double ux, double vy, double d) {
    double gx = (u - ux) / d;
    double gy = (v - vy) / d;
    if (gx < 0.0 || gy < 0.0 || gy >= 7.0) return 0;
    int col = (int)gx;
    int idx = col / 6;     //1文字は幅5+間隔1ドット
    int dx  = col % 6;
    if (dx >= 5) return 0;
    for (int i = 0; i <= idx; i++) if (!s[i]) return 0;
    const uint8_t *g = fubk_glyph(s[idx]);
    if (!g) return 0;
    return (g[(int)gy] >> (4 - dx)) & 1;
}

//中央パネルの色。u:-6..6 v:-5..5 thin:十字線の太さ(マス)
static RGBA fubk_panel(double u, double v, double thin) {
    const RGBA white = fubk_gray(1.0);
    const RGBA black = fubk_gray(0.0);
    const RGBA mid   = fubk_gray(0.5);

    //横の中央線(2T十字の横棒)
    if (fabs(v) <= thin * 0.5) return white;
    //縦の中央線(2T十字の縦棒)。三角の行は除く
    if (fabs(u) <= thin * 0.5 && v >= -2.0 && v < 2.0) return white;

    double x = u + 6.0; //パネル左端からの距離(0..12)

    //カラーバー: 白 黄 シアン 緑 マゼンタ 赤 青 黒(各1.5マス)
    if (v < -2.0) {
        const double L = FUBK_BAR_LEVEL;
        const RGBA bars[8] = {
            fubk_rgb(L, L, L), fubk_rgb(L, L, 0), fubk_rgb(0, L, L), fubk_rgb(0, L, 0),
            fubk_rgb(L, 0, L), fubk_rgb(L, 0, 0), fubk_rgb(0, 0, L), fubk_rgb(0, 0, 0),
        };
        int i = (int)(x / 1.5);
        if (i < 0) i = 0;
        if (i > 7) i = 7;
        return bars[i];
    }

    //グレースケール: 0 25 50 75 100%(各2.4マス)
    if (v < 0.0) {
        int i = (int)(x / 2.4);
        if (i < 0) i = 0;
        if (i > 4) i = 4;
        return fubk_gray(i / 4.0);
    }

    //黒区間(両脇は白)。中央の縦線を挟んで左右に文字欄を置く
    if (v < 1.0) {
        if (fabs(u) >= 3.6) return white;
        const double d = 0.085;      //1ドット(マス)。文字の高さは7ドット
        const double vy = 0.2;       //文字の上端
        if (fubk_text(FUBK_TEXT_LEFT,  u, v, -0.35 - 11 * d, vy, d)) return white;
        if (fubk_text(FUBK_TEXT_RIGHT, u, v,  0.35,          vy, d)) return white;
        return black;
    }

    //グレーティング: 白ブロック / 1MHz / 2MHz / 3MHz / 4.433MHz
    if (v < 2.0) {
        const double len = 86.0 / 48.0;
        if (x < 1.5) return white;
        if (u >= -4.2083 && u < -4.2083 + len) return fubk_grating(u + 4.2083, 1.0);
        if (u >= -2.1667 && u < -2.1667 + len) return fubk_grating(u + 2.1667, 2.0);
        if (u >=  0.3750 && u <  0.3750 + len) return fubk_grating(u - 0.3750, 3.0);
        if (u >=  2.5 && u < 5.5) {
#if FUBK_4433_AS_ORANGE
            return fubk_rgb(0.576, 0.446, 0.0);
#else
            return fubk_grating(u - 2.5, 4.433619);
#endif
        }
        return mid;
    }

    //下向きの三角(上端の半幅0.25マスから先端0へ)
    if (v < 3.0) {
        double t = v - 2.0;
        return (fabs(u) < 0.25 * (1.0 - t)) ? black : white;
    }

    //下段: 左はランプ(赤→黒 / 青→黒)、右は反PAL用の2x2マスのグレー
    if (u < 2.0) {
        double k = FUBK_BAR_LEVEL * (1.0 - x / 8.0);
        return (v < 4.0) ? fubk_rgb(k, 0, 0) : fubk_rgb(0, 0, k);
    }
    return mid;
}

void draw_fubk(Image *img) {
    if (!img || !img->data || img->width == 0 || img->height == 0) return;

    const double W = (double)img->width;
    const double H = (double)img->height;
    //格子ピッチ(px)。4:3なら W/19.2 == H/14.4。他の縦横比では中央に4:3で置く
    const double p  = fmin(W / 19.2, H / 14.4);
    const double cx = W * 0.5;
    const double cy = H * 0.5;
    const double tg = fmax(1.0, p * 0.05) / p; //線の太さ(マス単位、最低1px)
    const double R  = sqrt(45.0);

    const RGBA bg    = fubk_gray(0.25);
    const RGBA white = fubk_gray(1.0);

    for (uint64_t y = 0; y < img->height; y++) {
        for (uint64_t x = 0; x < img->width; x++) {
            double u = ((double)x + 0.5 - cx) / p;
            double v = ((double)y + 0.5 - cy) / p;
            double r = sqrt(u * u + v * v);
            RGBA c = bg;

            //格子(縦線)
            double ku = floor(u + 0.5);
            if (fabs(u - ku) <= tg * 0.5 && fabs(ku) <= 9.0 && fabs(v) <= 7.0 + tg * 0.5) c = white;
            //格子(横線)
            double kv = floor(v + 0.5);
            if (fabs(v - kv) <= tg * 0.5 && fabs(kv) <= 7.0 && fabs(u) <= 9.0 + tg * 0.5) c = white;

            //中央パネル(矩形のまま描く。円でクリップしない)
            if (fabs(u) <= 6.0 && fabs(v) <= 5.0) c = fubk_panel(u, v, tg * 1.5);

            //円
            if (fabs(r - R) <= tg * 0.5) c = white;

            img->data[y * img->width + x] = c;
        }
    }

	img->count = 1;
	img->fps = 0;
}