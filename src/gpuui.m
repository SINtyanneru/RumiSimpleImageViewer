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

#import "rsiv.h"
#import "format/format.h"

#define VIEW_ZOOM_DEFAULT 1.0f
#define VIEW_OFFSET_X 0.0f
#define VIEW_OFFSET_Y 0.0f

//シェーダー
static const uint8_t VS_SRC[] = {
	#embed "shader/unko.vert"
	,0
};
static const uint8_t FS_SRC[] = {
	#embed "shader/unko.frag"
	,0
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
static GLuint texture;
static GLuint vao;
static GLuint vbo;
static GLuint ebo;
static GLuint prog;

static float view_zoom = VIEW_ZOOM_DEFAULT;
static float view_offset_x = VIEW_OFFSET_X;
static float view_offset_y = VIEW_OFFSET_Y;

static BOOL view_is_dragging = NO;
static double view_last_x = 0.0f;
static double view_last_y = 0.0f;

//表示中の画像サイズ（オフセット制限用）
static int32_t view_img_w = 0;
static int32_t view_img_h = 0;

//画像の移動を制限する
//画像がウィンドウより大きいときは端まで、小さいときはウィンドウの内側まで。
//ただし、画像の四隅がウィンドウの中央に来るまでは許容する
static void clamp_view_offset() {
	int fw, fh;
	glfwGetFramebufferSize(window, &fw, &fh);

	float iw = (float)view_img_w * view_zoom;
	float ih = (float)view_img_h * view_zoom;

	float max_x = fabsf(iw - (float)fw) * 0.5f;
	float max_y = fabsf(ih - (float)fh) * 0.5f;

	//四隅が中央に来る位置
	float corner_x = iw * 0.5f;
	float corner_y = ih * 0.5f;
	if (corner_x > max_x) max_x = corner_x;
	if (corner_y > max_y) max_y = corner_y;

	if (view_offset_x > max_x) view_offset_x = max_x;
	if (view_offset_x < -max_x) view_offset_x = -max_x;
	if (view_offset_y > max_y) view_offset_y = max_y;
	if (view_offset_y < -max_y) view_offset_y = -max_y;
}

//ウィンドウ座標→フレームバッファ座標の比率(HiDPI対策)
static double pixel_ratio(GLFWwindow *window) {
	int ww, wh, fw, fh;
	glfwGetWindowSize(window, &ww, &wh);
	glfwGetFramebufferSize(window, &fw, &fh);
	if (ww == 0) return 1.0;
	return (double)fw / (double)ww;
}

//リサイズ時に呼ばれる
static void framebuffer_size_callback(GLFWwindow *window, int width, int height) {
	glViewport(0, 0, width, height);
	clamp_view_offset();
}

//スクロールで拡大縮小(カーソル位置を中心に)
static void scroll_callback(GLFWwindow *window, double xoff, double yoff) {
	double mx, my;
	glfwGetCursorPos(window, &mx, &my);
	double r = pixel_ratio(window);

	int fw, fh;
	glfwGetFramebufferSize(window, &fw, &fh);

	//画面中心を原点、上を正にしたカーソル座標
	float cx = (float)(mx * r) - fw * 0.5f;
	float cy = fh * 0.5f - (float)(my * r);

	float new_zoom = view_zoom * powf(1.1f, (float)yoff);
	if (new_zoom < 0.01f) new_zoom = 0.01f;
	if (new_zoom > 200.0f) new_zoom = 200.0f;

	float k = new_zoom / view_zoom;
	view_offset_x = cx - (cx - view_offset_x) * k;
	view_offset_y = cy - (cy - view_offset_y) * k;
	view_zoom = new_zoom;
	clamp_view_offset();
}

//クリック開始/終了
static void mouse_button_callback(GLFWwindow *window, int button, int action, int mods) {
	if (button == GLFW_MOUSE_BUTTON_LEFT) {
		if (action == GLFW_PRESS) {
			view_is_dragging = YES;
			glfwGetCursorPos(window, &view_last_x, &view_last_y);
		} else if (action == GLFW_RELEASE) {
			view_is_dragging = NO;
		}
	}
}

//ドラッグ中の移動
static void cursor_pos_callback(GLFWwindow *window, double x, double y) {
	if (view_is_dragging) {
		double r = pixel_ratio(window);
		view_offset_x += (float)((x - view_last_x) * r);
		view_offset_y -= (float)((y - view_last_y) * r);
		view_last_x = x;
		view_last_y = y;
		clamp_view_offset();
	}
}

//ドラドロ
void drop_callback(GLFWwindow *window, int count, const char **pathlp) {
	SharedImage *shared_image = glfwGetWindowUserPointer(window);

	pthread_mutex_lock(&shared_image->dd.lock);

	un_list_clear(shared_image->dd.path_list);

	for (int i = 0; i < count; i++) {
		if (pathlp[i] != NULL) un_list_add(shared_image->dd.path_list, pathlp[i]);
	}

	pthread_mutex_unlock(&shared_image->dd.lock);
}

BOOL create_window() {
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
#ifdef __APPLE__
	//macOS でコアプロファイルを作るには前方互換の指定が要る
	glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
#endif

	window = glfwCreateWindow(800, 600, "RSIV - んご", NULL, NULL);
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
	glfwSetScrollCallback(window, scroll_callback);
	glfwSetMouseButtonCallback(window, mouse_button_callback);
	glfwSetCursorPosCallback(window, cursor_pos_callback);
	glfwSetDropCallback(window, drop_callback);

	return YES;
}

void create_texture(Image *img) {
	glGenTextures(1, &texture);
	glBindTexture(GL_TEXTURE_2D, texture);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, img->width, img->height, 0, GL_RGBA, GL_UNSIGNED_BYTE, img->data);

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

void create_shader() {
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

void reset_view(Image *img) {
	view_zoom = VIEW_ZOOM_DEFAULT;
	view_offset_x = VIEW_OFFSET_X;
	view_offset_y = VIEW_OFFSET_Y;
	view_img_w = img->width;
	view_img_h = img->height;

	int32_t fw;
	int32_t fh;
	glfwGetFramebufferSize(window, &fw, &fh);
	glViewport(0, 0, fw, fh);

	//ウィンドウに収まる大きさを計算する
	{
		float sx = (float)fw / (float)img->width;
		float sy = (float)fh / (float)img->height;
		view_zoom = sx < sy ? sx : sy;
	}
}

void ui_loop(Image *img, SharedImage *shared_image, int32_t fw, int32_t fh) {
	GLint loc_win = glGetUniformLocation(prog, "u_win");
	GLint loc_img = glGetUniformLocation(prog, "u_img");
	GLint loc_off = glGetUniformLocation(prog, "u_off");
	GLint loc_zoom = glGetUniformLocation(prog, "u_zoom");

	uint32_t image_last_version = 0;
	uint32_t title_last_version = 0;

	uint32_t texture_w = img->width;
	uint32_t texture_h = img->height;
	double animation_time = glfwGetTime();
	int64_t cur_frame = -1;

	while (!glfwWindowShouldClose(window)) {
		glfwGetFramebufferSize(window, &fw, &fh);

		//画像の更新検知
		uint32_t image_v = __atomic_load_n(&shared_image->version, __ATOMIC_SEQ_CST);
		if (image_v != image_last_version) {
			pthread_mutex_lock(&shared_image->lock);

			memcpy(img, shared_image->image, sizeof(Image));

			glBindTexture(GL_TEXTURE_2D, texture);
			if (img->width != texture_w || img->height != texture_h) {
				glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, img->width, img->height, 0, GL_RGBA, GL_UNSIGNED_BYTE, img->data);
				texture_w = img->width;
				texture_h = img->height;
			} else {
				glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, img->width, img->height, GL_RGBA, GL_UNSIGNED_BYTE, img->data);
			}

			image_last_version = __atomic_load_n(&shared_image->version, __ATOMIC_SEQ_CST);

			pthread_mutex_unlock(&shared_image->lock);

			//初期化
			animation_time = glfwGetTime();
			cur_frame = -1;
			reset_view(img);
		}

		//画像の更新検知
		uint32_t title_v = __atomic_load_n(&shared_image->title_bar.version, __ATOMIC_SEQ_CST);
		if (title_v != title_last_version) {
			pthread_mutex_lock(&shared_image->title_bar.lock);

			glfwSetWindowTitle(window, shared_image->title_bar.title);

			title_last_version = __atomic_load_n(&shared_image->title_bar.version, __ATOMIC_SEQ_CST);

			pthread_mutex_unlock(&shared_image->title_bar.lock);
		}

		//アニメーション
		if (img->fps != 0 && img->count > 1) {
			double elapsed = glfwGetTime() - animation_time;
			int32_t frame = (int32_t)(elapsed / img->fps) % img->count;
			if (frame != cur_frame) {
				cur_frame = frame;
				const uint8_t *src = (const uint8_t *)(img->data + (size_t)frame * img->width * img->height);
				glBindTexture(GL_TEXTURE_2D, texture);
				glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, img->width, img->height, GL_RGBA, GL_UNSIGNED_BYTE, src);
			}
		}

		glClearColor(0.1f, 0.2f, 0.3f, 1.0f);
		glClear(GL_COLOR_BUFFER_BIT);

		glUniform2f(loc_win, (float)fw, (float)fh);
		glUniform2f(loc_img, (float)img->width, (float)img->height);
		glUniform2f(loc_off, view_offset_x, view_offset_y);
		glUniform1f(loc_zoom, view_zoom);

		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, texture);
		glBindVertexArray(vao);
		glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);

		glfwSwapBuffers(window);
		glfwPollEvents();
	}
}

void gpuui_main(SharedImage *shared_image) {
	Image img;

	//初回ロード
	pthread_mutex_lock(&shared_image->lock);
	memcpy(&img, shared_image->image, sizeof(Image));
	pthread_mutex_unlock(&shared_image->lock);

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

	glfwSetWindowUserPointer(window, shared_image);

	int32_t fw;
	int32_t fh;
	glfwGetFramebufferSize(window, &fw, &fh);
	glViewport(0, 0, fw, fh);
	reset_view(&img);

	create_texture(&img);
	create_shader();

	//描画ループとか
	ui_loop(&img, shared_image, fw, fh);

	//後掃除
	glDeleteTextures(1, &texture);
	glDeleteProgram(prog);
	glDeleteBuffers(1, &vbo);
	glDeleteBuffers(1, &ebo);
	glDeleteVertexArrays(1, &vao);
	glfwDestroyWindow(window);
	glfwTerminate();

	exit(0);

	return;
}