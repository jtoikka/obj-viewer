library deferred;

import 'dart:web_gl';
import 'dart:js';

class DeferredFBO {
	Texture depthTex;
	Texture normalTex;
	Texture albedoTex;

	Texture shadowTex;
	Texture fooTex;

	Texture finalTex;

	Framebuffer baseFbo;
	Framebuffer shadowFbo;
	Framebuffer finalFbo;

	DeferredFBO(int w, int h, RenderingContext gl) {
		print("Init draw buffers");
	    DrawBuffers extension = gl.getExtension('WEBGL_draw_buffers');
	    if (extension == null) {
	        print("ERROR: Draw buffers not supported");
	    }

	    print("Gen textures");
		genTextures(w, h, gl);
		print("Gen base fbo");
		genBaseFbo(gl, extension);
		print("Gen shadow fbo");
		genShadowFbo(gl, extension);
		print("Gen final fbo");
		genFinalFbo(gl, extension);
	}

	void genBaseFbo(RenderingContext gl, DrawBuffers extension) {

		baseFbo = gl.createFramebuffer();

		gl.bindFramebuffer(FRAMEBUFFER, baseFbo);
		gl.framebufferTexture2D(FRAMEBUFFER, DEPTH_ATTACHMENT,
		                        TEXTURE_2D, depthTex, 0);
		gl.framebufferTexture2D(FRAMEBUFFER, COLOR_ATTACHMENT0,
		                        TEXTURE_2D, normalTex, 0);
		gl.framebufferTexture2D(FRAMEBUFFER, COLOR_ATTACHMENT0 + 1,
		                        TEXTURE_2D, albedoTex, 0);

		List colorAttachments = [COLOR_ATTACHMENT0,
                                 COLOR_ATTACHMENT0 + 1];

        print("Color attachments");
		extension.drawBuffersWebgl(colorAttachments);

		print("Status");
		var FBOstatus = gl.checkFramebufferStatus(FRAMEBUFFER);
        if (FBOstatus != FRAMEBUFFER_COMPLETE) {
     		print("ERROR: Framebuffer incomplete");
        }
        gl.bindFramebuffer(FRAMEBUFFER, null);
	}

	void genShadowFbo(RenderingContext gl, DrawBuffers extension) {
		shadowFbo = gl.createFramebuffer();

		gl.bindFramebuffer(FRAMEBUFFER, shadowFbo);

		// Because of bugs with depth textures, we need to add a color texture
		gl.framebufferTexture2D(FRAMEBUFFER, DrawBuffers.COLOR_ATTACHMENT0_WEBGL,
		                        TEXTURE_2D, fooTex, 0);
		gl.framebufferTexture2D(FRAMEBUFFER, DEPTH_ATTACHMENT,
                        TEXTURE_2D, shadowTex, 0);

		var FBOstatus = gl.checkFramebufferStatus(FRAMEBUFFER);
        if (FBOstatus != FRAMEBUFFER_COMPLETE) {
     		print("ERROR: Framebuffer incomplete");
        }
        gl.bindFramebuffer(FRAMEBUFFER, null);
	}

	void genFinalFbo(RenderingContext gl, DrawBuffers extension) {
		finalFbo = gl.createFramebuffer();

		gl.bindFramebuffer(FRAMEBUFFER, finalFbo);

		gl.framebufferTexture2D(FRAMEBUFFER, DrawBuffers.COLOR_ATTACHMENT0_WEBGL,
								TEXTURE_2D, finalTex, 0);

		// List colorAttachments = [DrawBuffers.COLOR_ATTACHMENT0_WEBGL];

		// extension.drawBuffersWebgl(colorAttachments);

		var FBOstatus = gl.checkFramebufferStatus(FRAMEBUFFER);
		if (FBOstatus != FRAMEBUFFER_COMPLETE) {
			print("ERROR: Framebuffer incomplete");
		}
		gl.bindFramebuffer(FRAMEBUFFER, null);
	}

//	void genFBO1(RenderingContext gl, DrawBuffers extension) {
//		fbo1 = gl.createFramebuffer();
//
//		gl.bindFramebuffer(FRAMEBUFFER, fbo1);
//		gl.framebufferTexture2D()
//	}

	Texture genTexture(RenderingContext gl, int internalFormat,
	                   int w, int h, int format, int type) {
		Texture tex = gl.createTexture();
		gl.bindTexture(TEXTURE_2D, tex);
		gl.texImage2DTyped(TEXTURE_2D, 0, internalFormat, w, h, 0, format, type, null);
		gl.texParameteri(TEXTURE_2D, TEXTURE_MIN_FILTER, NEAREST);
		gl.texParameteri(TEXTURE_2D, TEXTURE_MAG_FILTER, NEAREST);
		gl.texParameteri(TEXTURE_2D, TEXTURE_WRAP_S, CLAMP_TO_EDGE);
		gl.texParameteri(TEXTURE_2D, TEXTURE_WRAP_T, CLAMP_TO_EDGE);

		return tex;
	}

	void genTextures(int w, int h, RenderingContext gl) {
		depthTex = genTexture(gl, DEPTH_COMPONENT, w, h,
							  DEPTH_COMPONENT, UNSIGNED_INT);
		normalTex = genTexture(gl, RGB, w, h, RGB, FLOAT);
		albedoTex = genTexture(gl, RGBA, w, h, RGBA, FLOAT);

		shadowTex = genTexture(gl, DEPTH_COMPONENT, 1024, 1024,
							  DEPTH_COMPONENT, UNSIGNED_INT);
		gl.texParameteri(TEXTURE_2D, TEXTURE_MIN_FILTER, LINEAR);
        gl.texParameteri(TEXTURE_2D, TEXTURE_MAG_FILTER, LINEAR);
		fooTex = genTexture(gl, RGB, 1024, 1024, RGB, FLOAT);

		finalTex = genTexture(gl, RGBA, w, h, RGBA, FLOAT);
	}


}