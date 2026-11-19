#pragma clang diagnostic ignored "-Wc23-extensions"

#ifdef __APPLE__
//macOS では GLEW は使わない（glfw3.h に <OpenGL/gl3.h> を読ませる）
#define GLFW_INCLUDE_GLCOREARB
#else
#import <GL/glew.h>
#import <GL/gl.h>
#endif
#import <pthread.h>
#import <GLFW/glfw3.h>
#import <stdio.h>
#import <stdint.h>
#import <stdlib.h>
#import <math.h>
#import <stdatomic.h>
#import <string.h>
#import <ft2build.h>
#import FT_FREETYPE_H

#import "rsiv.h"
#import "format/format.h"
#import "main.h"

#define DEFAULT_WINDOW_WIDTH 800
#define DEFAULT_WINDOW_HEIGHT 600

//シェーダー
static const uint8_t VS_SRC[] = {
	#embed "shader/unko.vert"
	,0
};
static const uint8_t FS_SRC[] = {
	#embed "shader/unko.frag"
	,0
};

//フォント
static const uint8_t FONT[] = {
	#embed "../UDEVGothic-Regular.ttf"
};

//頂点(フルスクリーンクアッド)
//pos(x,y) uv(u,v)  ※vを反転して、配列の先頭行が画面の上に来るようにしている
static const float VERT_LIST[] = {
	-1.0f, -1.0f, 0.0f, 1.0f,
	1.0f, -1.0f, 1.0f, 1.0f,
	1.0f,  1.0f, 1.0f, 0.0f,
	-1.0f,  1.0f, 0.0f, 0.0f,
};
static const uint32_t IDX[] = {0, 1, 2, 2, 3, 0};

static GLFWwindow *window;
static GLuint vao;
static GLuint vbo;
static GLuint ebo;
static GLuint prog;
static FT_Library ft;
static FT_Face face;

//リサイズ時
static void framebuffer_size_callback(GLFWwindow *window, int width, int height) {
	glViewport(0, 0, width, height);

	on_window_resize((uint32_t)width, (uint32_t)height);
}

//キー関係
static void key_callback(GLFWwindow *window, int key, int scancode, int action, int mods) {
	if (action == GLFW_PRESS) {
		on_key_press(key, mods);
	} else if (action == GLFW_RELEASE) {
		on_key_release(key, mods);
	} else if (action == GLFW_REPEAT) {
		on_key_pressing(key, mods);
	}
}

//マウスクリック関係
static void mouse_button_callback(GLFWwindow *window, int button, int action, int mods) {
	if (action == GLFW_PRESS) {
		on_mouse_click(button);
	} else if (action == GLFW_RELEASE) {
		on_mouse_release(button);
	}
}

//マウス移動関係
static void cursor_move_callback(GLFWwindow *window, double x, double y) {
	on_mouse_move(x, y);
}

//スクロール関係
static void scroll_callback(GLFWwindow *window, double delta_x, double delta_y) {
	on_mouse_scroll(delta_x, delta_y);
}

//ドラドロ
void drop_callback(GLFWwindow *window, int count, const char **pathlp) {
	on_dd(count, pathlp);
}

static BOOL create_window() {
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
#ifdef __APPLE__
	//macOS でコアプロファイルを作るには前方互換の指定が要る
	glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
#endif

	window = glfwCreateWindow(DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT, "RSIV - んご", NULL, NULL);
	if (!window) {
		fprintf(stderr, "Window create failed\n");
		glfwTerminate();
		return NO;
	}

	glfwMakeContextCurrent(window);
	glfwSwapInterval(1);

#ifndef __APPLE__
	glewExperimental = GL_TRUE;
	if (glewInit() != GLEW_OK) {
		fprintf(stderr, "GLEW init failed\n");
		return NO;
	}
#endif

	glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);

	glfwSetKeyCallback(window, key_callback);
	glfwSetMouseButtonCallback(window, mouse_button_callback);
	glfwSetCursorPosCallback(window, cursor_move_callback);
	glfwSetScrollCallback(window, scroll_callback);

	glfwSetDropCallback(window, drop_callback);

	return YES;
}

static void create_geometry() {
	glGenVertexArrays(1, &vao);
	glGenBuffers(1, &vbo);
	glGenBuffers(1, &ebo);

	glBindVertexArray(vao);
	glBindBuffer(GL_ARRAY_BUFFER, vbo);
	glBufferData(GL_ARRAY_BUFFER, sizeof(VERT_LIST), VERT_LIST, GL_STATIC_DRAW);
	glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo);
	glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(IDX), IDX, GL_STATIC_DRAW);
	glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void *)0);
	glEnableVertexAttribArray(0);
	glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void *)(2 * sizeof(float)));
	glEnableVertexAttribArray(1);
}

static void create_shader() {
	const GLchar *vs_pointer = (const GLchar *)VS_SRC;
	const GLchar *fs_pointer = (const GLchar *)FS_SRC;
	GLint vs_length = sizeof(VS_SRC) - 1;
	GLint fs_length = sizeof(FS_SRC) - 1;
	GLuint vs = glCreateShader(GL_VERTEX_SHADER);
	GLuint fs = glCreateShader(GL_FRAGMENT_SHADER);
	glShaderSource(vs, 1, &vs_pointer, &vs_length);
	glShaderSource(fs, 1, &fs_pointer, &fs_length);
	glCompileShader(vs);
	glCompileShader(fs);

	prog = glCreateProgram();
	glAttachShader(prog, vs);
	glAttachShader(prog, fs);
	glLinkProgram(prog);
	glDeleteShader(vs);
	glDeleteShader(fs);

	glUseProgram(prog);
	glUniform1i(glGetUniformLocation(prog, "tex"), 0);
}

static uint32_t utf8_decode(const char **p) {
	const uint8_t *s = (const uint8_t *)*p;
	uint32_t cp;
	uint32_t n;
	if (s[0] < 0x80) {
		cp = s[0];
		n = 1;
	} else if ((s[0] & 0xE0) == 0xC0) {
		cp = s[0] & 0x1F;
		n = 2;
	} else if ((s[0] & 0xF0) == 0xE0) {
		cp = s[0] & 0x0F;
		n = 3;
	} else if ((s[0] & 0xF8) == 0xF0) {
		cp = s[0] & 0x07;
		n = 4;
	} else {
		*p += 1;
		return 0xFFFD;
	}
	for (uint32_t i = 1; i < n; i++) {
		if ((s[i] & 0xC0) != 0x80) {
			*p += 1;
			return 0xFFFD;
		}
		cp = (cp << 6) | (s[i] & 0x3F);
	}
	*p += n;
	return cp;
}

static void ui_loop(Image *img, UISharedData *shared, int32_t fw, int32_t fh) {
	GLint loc_win = glGetUniformLocation(prog, "u_win");
	GLint loc_pos = glGetUniformLocation(prog, "u_pos");
	GLint loc_size = glGetUniformLocation(prog, "u_size");
	GLint loc_color = glGetUniformLocation(prog, "u_color");

	uint32_t title_last_version = 0;

	while (!glfwWindowShouldClose(window)) {
		glfwGetFramebufferSize(window, &fw, &fh);
		glClearColor(0.1f, 0.2f, 0.3f, 1.0f);
		glClear(GL_COLOR_BUFFER_BIT);
		glUniform2f(loc_win, (float)fw, (float)fh);

		pthread_mutex_lock(&shared->uiitem_lock);

		for (int i = 0; i < UIITEM_LENGTH; i++) {
			UIItem *ui = &shared->item_list[i];
			if (ui->type == UIItem_None) continue;

			switch (ui->type) {
				case UIItem_Rect: {
					UIItemRect *r = (UIItemRect *)ui->item;
					if (r->texture == 0 || (r->texture_version != r->texture_synced_version)) {
						if (r->texture != 0) glDeleteTextures(1, &r->texture);

						uint8_t white_pixel[4] = {r->color.r, r->color.g, r->color.b, r->color.a};
						glGenTextures(1, &r->texture);
						glBindTexture(GL_TEXTURE_2D, r->texture);
						glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
						glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
						glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, white_pixel);

						r->texture_synced_version = r->texture_version;
					}

					glEnable(GL_BLEND);
					glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
					glUniform2f(loc_pos, (float)r->x, (float)r->y);
					glUniform2f(loc_size, (float)r->w, (float)r->h);

					glBindTexture(GL_TEXTURE_2D, r->texture);

					glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
					break;
				}

				case UIItem_Image: {
					UIItemImage *img = (UIItemImage *)ui->item;

					if (img->texture == 0 || (img->texture_version != img->texture_synced_version)) {
						if (img->texture != 0) glDeleteTextures(1, &img->texture);

						glGenTextures(1, &img->texture);
						glBindTexture(GL_TEXTURE_2D, img->texture);
						glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
						glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
						glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
						glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
						glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
						glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, img->img.width, img->img.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, img->img.data);

						img->texture_synced_version = img->texture_version;
					}

					glBindTexture(GL_TEXTURE_2D, img->texture);

					if (img->img.count > 1 && img->img.fps > 0) {
						if (img->anim_start == 0) img->anim_start = glfwGetTime();
						int32_t frame = (int32_t)((glfwGetTime() - img->anim_start) / img->img.fps) % img->img.count;
						if (frame != img->cur_frame) {
							img->cur_frame = frame;
							RGBA *src = img->img.data + (size_t)frame * img->img.width * img->img.height;
							glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, img->img.width, img->img.height, GL_RGBA, GL_UNSIGNED_BYTE, src);
						}
					}

					glUniform2f(loc_pos, (float)img->x, (float)img->y);
					glUniform2f(loc_size, (float)img->w, (float)img->h);
					glUniform4f(loc_color, 1.0f, 1.0f, 1.0f, 1.0f);
					glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
					break;
				}

				case UIItem_Text: {
					UIItemText *text_item = (UIItemText *)ui->item;
					if (text_item->texture == 0 || (text_item->texture_version != text_item->texture_synced_version)) {
						if (text_item->texture != 0) glDeleteTextures(1, &text_item->texture);

						Image img;
						FT_Set_Pixel_Sizes(face, 0, text_item->size);

						//1周目: 横幅を測る
						uint32_t total_w = 0;
						for (const char *p = text_item->text; *p != '\0'; ) {
							uint32_t cp = utf8_decode(&p); //UTF-8 を1文字読む小関数（自作）
							FT_Load_Char(face, cp, FT_LOAD_RENDER);
							total_w += face->glyph->advance.x >> 6;
						}

						//Image を確保（高さはフォントの行の高さ、基準線は ascender の位置）
						uint32_t h = (face->size->metrics.ascender - face->size->metrics.descender) >> 6;
						uint32_t baseline = face->size->metrics.ascender >> 6;

						img.width = total_w;
						img.height = h;
						img.count = 1;
						img.fps = 0;
						img.data = calloc((size_t)total_w * h, sizeof(RGBA));

						text_item->texture_w = total_w;
						text_item->texture_h = h;

						//2周目: 焼く
						uint32_t pen_x = 0;
						for (const char *p = text_item->text; *p != '\0'; ) {
							uint32_t cp = utf8_decode(&p);
							FT_Load_Char(face, cp, FT_LOAD_RENDER);
							FT_Bitmap *bm = &face->glyph->bitmap;
							int32_t gx = (int32_t)pen_x + face->glyph->bitmap_left;
							int32_t gy = (int32_t)baseline - face->glyph->bitmap_top;
							for (uint32_t y = 0; y < bm->rows; y++) {
								for (uint32_t x = 0; x < bm->width; x++) {
									int32_t px = gx + (int32_t)x;
									int32_t py = gy + (int32_t)y;
									if (px < 0 || py < 0 || px >= (int32_t)img.width || py >= (int32_t)img.height) continue;
									uint8_t cov = bm->buffer[y * bm->pitch + x];
									RGBA *dst = &img.data[py * img.width + px];
									dst->r = text_item->color.r;
									dst->g = text_item->color.g;
									dst->b = text_item->color.b;
									if (cov > dst->a) dst->a = cov;
								}
							}
							pen_x += face->glyph->advance.x >> 6;
						}

						glGenTextures(1, &text_item->texture);
						glBindTexture(GL_TEXTURE_2D, text_item->texture);
						glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
						glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
						glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
						glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
						glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, img.width, img.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, img.data);
						free(img.data);

						text_item->texture_synced_version = text_item->texture_version;
					}

					glEnable(GL_BLEND);
					glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
					glBindTexture(GL_TEXTURE_2D, text_item->texture);
					glUniform2f(loc_pos, (float)text_item->x, (float)text_item->y);
					glUniform2f(loc_size, (float)text_item->texture_w, (float)text_item->texture_h);
					glUniform4f(loc_color, 1.0f, 1.0f, 1.0f, 1.0f);
					glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);

					break;
				}

				default: {
					break;
				}
			}
		}

		pthread_mutex_unlock(&shared->uiitem_lock);

		//タイトルの更新検知
		uint32_t title_v = __atomic_load_n(&shared->title_bar.version, __ATOMIC_SEQ_CST);
		if (title_v != title_last_version) {
			pthread_mutex_lock(&shared->title_bar.lock);

			glfwSetWindowTitle(window, shared->title_bar.title);

			title_last_version = __atomic_load_n(&shared->title_bar.version, __ATOMIC_SEQ_CST);

			pthread_mutex_unlock(&shared->title_bar.lock);
		}

		main_loop();

		glfwSwapBuffers(window);
		glfwPollEvents();
	}
}

void gpuui_main(UISharedData *shared) {
	Image img;

	FT_Init_FreeType(&ft);
	FT_New_Memory_Face(ft, FONT, sizeof(FONT), 0, &face);

	//初回ロード
	// pthread_mutex_lock(&shared->lock);
	// memcpy(&img, shared->image, sizeof(Image));
	// pthread_mutex_unlock(&shared->lock);

	//初期化
	if (glfwInit() == NO) {
		fprintf(stderr, "GLFW init failed\n");
		exit(1);
		return;
	}

	//ウィンドウを作る
	if (create_window() == NO) {
		exit(1);
		return;
	}

	glfwSetWindowUserPointer(window, shared);

	int32_t fw;
	int32_t fh;
	glfwGetFramebufferSize(window, &fw, &fh);
	glViewport(0, 0, fw, fh);

	create_geometry();
	create_shader();

	//描画ループとか
	ui_loop(&img, shared, fw, fh);

	//後掃除
	//glDeleteTextures(1, &texture);
	glDeleteProgram(prog);
	glDeleteBuffers(1, &vbo);
	glDeleteBuffers(1, &ebo);
	glDeleteVertexArrays(1, &vao);
	glfwDestroyWindow(window);
	glfwTerminate();

	exit(0);

	return;
}

uint32_t get_screen_width() {
	if (window == NULL) return DEFAULT_WINDOW_WIDTH;

	int fw, fh;
	glfwGetFramebufferSize(window, &fw, &fh);

	return (uint32_t)fw;
}

uint32_t get_screen_height() {
	if (window == NULL) return DEFAULT_WINDOW_HEIGHT;

	int fw, fh;
	glfwGetFramebufferSize(window, &fw, &fh);

	return (uint32_t)fh;
}