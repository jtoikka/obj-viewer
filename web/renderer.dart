import 'dart:core';
import 'dart:web_gl';
import 'dart:typed_data';
import 'dart:math';
import 'dart:collection';
import 'dart:html';

import 'shaderManager.dart';
import 'deferredFBO.dart';
import 'camera.dart';
import 'package:vector_math/vector_math.dart';
import 'package:obj/obj.dart';

class Model {
	Buffer vertexBuffer;
	Buffer normalBuffer;
	Buffer indexBuffer;
	int numIndices;
}

class Renderer {
    var positionLocation;
    var program;
    Buffer screenBuffer;
    Buffer screenIndexBuffer;
    Buffer screenUVBuffer;

    Buffer cubeBuffer;
    Buffer cubeIndexBuffer;

    Buffer planeVertexBuffer;
    Buffer planeNormalBuffer;
    Buffer planeIndexBuffer;

    Matrix4 cameraToClipMatrix;
    Queue<Matrix4> matrixStack;

    Matrix4 orthoMatrix;
    Matrix4 bias;
    Matrix4 worldToCamera;

    Map<String, Model> models = new Map();
    Obj tempObj;

    ShaderManager shaderManager;
    DeferredFBO deferredFBO;

    Random rng;
    Texture noiseTex;

    Renderer(RenderingContext gl, int width, int height) {
        print("Init shaderManager");
        shaderManager = new ShaderManager();
        print("Init deferredFBO");
        deferredFBO = new DeferredFBO(width, height, gl);
        print("Init programs");
        shaderManager.initProgram(gl, "entity", "#vertex-shader", "#fragment-shader");
        shaderManager.initProgram(gl, "basic", "#basic-vs", "#basic-fs");
        shaderManager.initProgram(gl, "light", "#light-vs", "#light-fs");
        shaderManager.initProgram(gl, "sky", "#sky-vs", "#sky-fs");
        shaderManager.initProgram(gl, "post", "#post-vs", "#post-fs");

        shaderManager.attachTexture(gl, "basic", "depthTex", 0);
        shaderManager.attachTexture(gl, "basic", "normalTex", 1);
        shaderManager.attachTexture(gl, "basic", "albedoTex", 2);
        shaderManager.attachTexture(gl, "basic", "shadowTex", 3);
        shaderManager.attachTexture(gl, "basic", "noiseTex", 4);

        shaderManager.attachTexture(gl, "post", "tex", 0);

        initScreenQuad(gl);
        initPlane(gl);

        initCameraToClipMatrix(gl, width, height);
        matrixStack = new Queue();
        loadIdentity();

        var basicProgram = shaderManager.getProgram("basic");
        gl.useProgram(basicProgram.handle);

        var unif = gl.getUniformLocation(
            basicProgram.handle, "modelToCameraMatrix");
        basicProgram.unifs["modelToCam"] = unif;

        unif = gl.getUniformLocation(
            basicProgram.handle, "lightMatrix");
        basicProgram.unifs["lightMatrix"] = unif;

        unif = gl.getUniformLocation(basicProgram.handle, "specExp");
        basicProgram.unifs["specExp"] = unif;

        unif = gl.getUniformLocation(basicProgram.handle, "specInt");
        basicProgram.unifs["specInt"] = unif;

        unif = gl.getUniformLocation(basicProgram.handle, "roughness");
        basicProgram.unifs["roughness"] = unif;

        unif = gl.getUniformLocation(basicProgram.handle, "exposure");
        basicProgram.unifs["exposure"] = unif;

        unif = gl.getUniformLocation(basicProgram.handle, "diffuseInt");
        basicProgram.unifs["diffuseInt"] = unif;


        var entityProgram = shaderManager.getProgram("entity");
        gl.useProgram(entityProgram.handle);
        unif = gl.getUniformLocation(
                entityProgram.handle, "modelToCameraMatrix");
        entityProgram.unifs["modelToCam"] = unif;
        entityProgram.unifs["colour"] =
                gl.getUniformLocation(entityProgram.handle, "colour");

        var lightProgram = shaderManager.getProgram("light");
        gl.useProgram(lightProgram.handle);
        unif = gl.getUniformLocation(
                lightProgram.handle, "modelToCameraMatrix");
        lightProgram.unifs["modelToCam"] = unif;
        lightProgram.unifs["colour"] =
                gl.getUniformLocation(lightProgram.handle, "colour");

        var postProgram = shaderManager.getProgram("post");
        gl.useProgram(postProgram.handle);
        var texelSizeUnif = gl.getUniformLocation(postProgram.handle, "texelSize");
        postProgram.unifs["texelSize"] = texelSizeUnif;

        gl.uniform2f(texelSizeUnif, 1.0/width.toDouble(), 1.0/height.toDouble());

        print("Getting dragon");
        loadObj(window.location.origin + "/data/dragon3.obj", "teapot", gl);

        gl.enable(CULL_FACE);
    	gl.cullFace(BACK);
    	gl.frontFace(CCW);
    	gl.depthMask(true);
    	gl.depthFunc(LESS);
    	gl.depthRange(0.0, 1.0);
    	gl.clearDepth(1.0);

    	bias = new Matrix4(
                        0.5, 0.0, 0.0, 0.5,
                        0.0, 0.5, 0.0, 0.5,
                        0.0, 0.0, 0.5, 0.5,
                        0.0, 0.0, 0.0, 1.0);

    	rng = new Random(9834592239); // Button-mashed seed, to keep it
    								  // consistent between sessions

    	noiseTex = genNoiseTex(gl);
    	genRotationKernel(gl);
    }

/*
Creates a screen quad. This is the quad used to render FBOs.
*/
    void initScreenQuad(RenderingContext gl) {
        screenBuffer = gl.createBuffer();
        screenUVBuffer = gl.createBuffer();
        screenIndexBuffer = gl.createBuffer();

        var vertices = [-1.0, -1.0,
                         1.0, -1.0,
                        -1.0,  1.0,
                         1.0,  1.0];

        var uv = [0.0, 0.0,
        		  1.0, 0.0,
        		  0.0, 1.0,
        		  1.0, 1.0];

        var indices = [0, 1, 2,
        			   2, 1, 3];

        gl.bindBuffer(ARRAY_BUFFER, screenBuffer);
        gl.bufferData(ARRAY_BUFFER, new Float32List.fromList(vertices), STATIC_DRAW);

        gl.bindBuffer(ARRAY_BUFFER, screenUVBuffer);
        gl.bufferData(ARRAY_BUFFER, new Float32List.fromList(uv), STATIC_DRAW);

        gl.bindBuffer(ELEMENT_ARRAY_BUFFER, screenIndexBuffer);
        gl.bufferData(ELEMENT_ARRAY_BUFFER, new Uint16List.fromList(indices), STATIC_DRAW);
    }

/*
Creates a plane, at height 0.0.
*/
    void initPlane(RenderingContext gl) {
    	planeVertexBuffer = gl.createBuffer();
    	planeNormalBuffer = gl.createBuffer();
    	planeIndexBuffer = gl.createBuffer();

    	var vertices = [-20.0, 0.0,  20.0,
    					 20.0, 0.0,  20.0,
    					 20.0, 0.0, -20.0,
    					-20.0, 0.0, -20.0];

    	var normals = [0.0, 1.0, 0.0,
    				   0.0, 1.0, 0.0,
    				   0.0, 1.0, 0.0,
    				   0.0, 1.0, 0.0];

    	var indices = [0, 1, 2,
    				   0, 2, 3];

    	gl.bindBuffer(ARRAY_BUFFER, planeVertexBuffer);
    	gl.bufferData(ARRAY_BUFFER, new Float32List.fromList(vertices), STATIC_DRAW);

    	gl.bindBuffer(ARRAY_BUFFER, planeNormalBuffer);
    	gl.bufferData(ARRAY_BUFFER, new Float32List.fromList(normals), STATIC_DRAW);

    	gl.bindBuffer(ELEMENT_ARRAY_BUFFER, planeIndexBuffer);
    	gl.bufferData(ELEMENT_ARRAY_BUFFER, new Uint16List.fromList(indices), STATIC_DRAW);

    }

/*
Creates a cube (for debugging).
*/
    // void initCube(RenderingContext gl) {
    //     cubeBuffer = gl.createBuffer();
    //     cubeIndexBuffer = gl.createBuffer();

    //     var vertices = [-0.5, -0.5,  0.5,
    //     				 0.5, -0.5,  0.5,
    //     				 0.5,  0.5,  0.5,
    //     				-0.5,  0.5,  0.5,

    //     				 0.5, -0.5, -0.5,
    //     				-0.5, -0.5, -0.5,
    //     				-0.5,  0.5, -0.5,
    //     				 0.5,  0.5, -0.5];

    //     var indices = [0, 1, 2,
    //     			   0, 2, 3,

    //     			   1, 4, 7,
    //     			   1, 7, 2,

    //     			   4, 5, 6,
    //     			   4, 6, 7,

    //     			   5, 0, 3,
    //     			   5, 3, 6,

    //     			   5, 4, 1,
    //     			   5, 1, 0,

    //     			   3, 2, 7,
    //     			   3, 7, 6];

    //     gl.bindBuffer(ARRAY_BUFFER, cubeBuffer);
    //     gl.bufferData(ARRAY_BUFFER, new Float32List.fromList(vertices), STATIC_DRAW);

    //     gl.bindBuffer(ELEMENT_ARRAY_BUFFER, cubeIndexBuffer);
    //     gl.bufferData(ELEMENT_ARRAY_BUFFER, new Uint16List.fromList(indices), STATIC_DRAW);
    // }

/*
Takes a file location, returns an Obj.
*/
    Obj handleObj(String objString) {
	    Obj obj = new Obj.fromString("url", objString);
	    return obj;
	}

/*
Takes an obj, creates buffers for it, and saves the resulting model in the
"models" collection.
*/
	void objToModel(Obj obj, String name, RenderingContext gl) {
		Buffer vertexBuffer = gl.createBuffer();
		gl.bindBuffer(ARRAY_BUFFER, vertexBuffer);
		gl.bufferData(ARRAY_BUFFER,
					  new Float32List.fromList(obj.vertCoord), STATIC_DRAW);

		Buffer normalBuffer = gl.createBuffer();
		gl.bindBuffer(ARRAY_BUFFER, normalBuffer);
		gl.bufferData(ARRAY_BUFFER,
					  new Float32List.fromList(obj.normCoord), STATIC_DRAW);

		Buffer indexBuffer = gl.createBuffer();
		gl.bindBuffer(ELEMENT_ARRAY_BUFFER, indexBuffer);
		gl.bufferData(ELEMENT_ARRAY_BUFFER,
					  new Uint16List.fromList(obj.indices), STATIC_DRAW);

		Model model = new Model();
		model.vertexBuffer = vertexBuffer;
		model.normalBuffer = normalBuffer;
		model.indexBuffer = indexBuffer;
		model.numIndices = obj.indices.length;
		models[name] = model;
	}

/*
Loads a .obj file, generates buffers for it, and saves the model in the "models"
collection (see: objToModel()).
*/
    void loadObj(String objURL, String name, RenderingContext gl) {
    	HttpRequest.getString(objURL)
    		.then(handleObj)
  			.then((obj) {
  			    objToModel(obj, name, gl);
  			});
    }

/*
Calculates frustum scale from field of view specified in degrees.
*/
    double calcFrustumScale(double fovDeg) {
        const double degToRad = 3.141592654 * 2.0 / 360.0;
        double fovRad = fovDeg * degToRad;
        return 1.0 / tan(fovRad / 2.0);
    }

/*
Initialized the orthographic projection matrix used for rendering the scene from
the light's perspective.
*/
    void orthographicProjection(RenderingContext gl, int w, int h) {
    	var zNear = -20;
        var zFar = 100;
        int width = 30;
        int height = 30;
    	orthoMatrix = new Matrix4.identity();
    	orthoMatrix[0] = 2 / width;
    	orthoMatrix[5] = 2 / height;
    	orthoMatrix[10] = -2 / (zFar - zNear);
    	orthoMatrix[14] = -(zFar + zNear) / (zFar - zNear);

    	var light = shaderManager.getProgram("light");

    	gl.useProgram(light.handle);
        var unif = gl.getUniformLocation(light.handle, "cameraToClipMatrix");
        gl.uniformMatrix4fv(unif, false, orthoMatrix.storage);
        gl.useProgram(null);
    }

/*
Initializes the camera to clip matrix, which (should) remain static.
*/
    void initCameraToClipMatrix(RenderingContext gl, int w, int h) {
        cameraToClipMatrix = new Matrix4.zero();
        var frustumScale = calcFrustumScale(45.0); // 45.0 degree field of view

        var zNear = 1.1;
        var zFar = 100.0;

        cameraToClipMatrix[0] = frustumScale / (w.toDouble() / h.toDouble());
        cameraToClipMatrix[5] = frustumScale;
        cameraToClipMatrix[10] = (zFar + zNear) / (zNear - zFar);
        cameraToClipMatrix[11] = -1.0;
        cameraToClipMatrix[14] = (2 * zFar * zNear) / (zNear - zFar);

        var basic = shaderManager.getProgram("basic");
        var entity = shaderManager.getProgram("entity");

        gl.useProgram(basic.handle);
        var unif = gl.getUniformLocation(basic.handle, "cameraToClipMatrix");
        gl.uniformMatrix4fv(unif, false, cameraToClipMatrix.storage);

        gl.useProgram(entity.handle);
        unif = gl.getUniformLocation(entity.handle, "cameraToClipMatrix");
        gl.uniformMatrix4fv(unif, false, cameraToClipMatrix.storage);
        gl.useProgram(null);

        orthographicProjection(gl, w, h);
    }

/*
Set the model to world matrix to an identity matrix (no translations, scales,
or rotations).
*/
    void loadIdentity() {
    	matrixStack.clear();
    	matrixStack.addLast(new Matrix4.identity());
    }

/*
Calculates the model to camera matrix (from the model to world, and world to
camera matrices), and sets the uniform for the currently bound shader program.
*/
    void setModelToCameraMatrix(RenderingContext gl,
                                Camera camera, var modelToCameraUnif) {
    	worldToCamera = camera.getLookMatrix();
    	Matrix4 modelToCamera = worldToCamera * matrixStack.last;
    	gl.uniformMatrix4fv(modelToCameraUnif, false, modelToCamera.storage);
    }

/*
Sets the matrix used to reconstruct position in the light's view from world
space.
*/
    void setLightMatrix(RenderingContext gl, Camera camera,
    					var modelToCameraUnif) {
        Matrix4 inv = new Matrix4.copy(worldToCamera);
        inv.invert();
        Matrix4 mat = orthoMatrix * camera.getLookMatrix() * inv;

        gl.uniformMatrix4fv(modelToCameraUnif, false, mat.storage);
    }

/*
Takes the information from the first "base" run, and calculates lighting,
ultimately rendering to the canvas's buffer.
*/
    void renderToScreen(RenderingContext gl, Camera camera, Camera lightCam) {
    	gl.bindFramebuffer(FRAMEBUFFER, deferredFBO.finalFbo);
		var program = shaderManager.getProgram("basic");
		gl.useProgram(program.handle);

		setLightMatrix(gl, lightCam, program.unifs["lightMatrix"]);
		setModelToCameraMatrix(gl, camera, program.unifs["modelToCam"]);

		gl.activeTexture(TEXTURE0);
		gl.bindTexture(TEXTURE_2D, deferredFBO.depthTex);

		gl.activeTexture(TEXTURE1);
		gl.bindTexture(TEXTURE_2D, deferredFBO.normalTex);

		gl.activeTexture(TEXTURE2);
		gl.bindTexture(TEXTURE_2D, deferredFBO.albedoTex);

		gl.activeTexture(TEXTURE3);
		gl.bindTexture(TEXTURE_2D, deferredFBO.shadowTex);

		gl.activeTexture(TEXTURE4);
		gl.bindTexture(TEXTURE_2D, noiseTex);

		gl.enableVertexAttribArray(program.vertex);
		gl.enableVertexAttribArray(program.uv);

		gl.bindBuffer(ARRAY_BUFFER, screenBuffer);
		gl.vertexAttribPointer(program.vertex, 2, FLOAT, false, 0, 0);
		gl.bindBuffer(ARRAY_BUFFER, screenUVBuffer);
		gl.vertexAttribPointer(program.uv, 2, FLOAT, false, 0, 0);
		gl.bindBuffer(ELEMENT_ARRAY_BUFFER, screenIndexBuffer);
		gl.drawElements(TRIANGLES, 6, UNSIGNED_SHORT, 0);

		program = shaderManager.getProgram("post");
		gl.useProgram(program.handle);

		gl.bindFramebuffer(FRAMEBUFFER, null);

		gl.activeTexture(TEXTURE0);
		gl.bindTexture(TEXTURE_2D, deferredFBO.finalTex);

		gl.drawElements(TRIANGLES, 6, UNSIGNED_SHORT, 0);

		gl.disableVertexAttribArray(program.vertex);
		gl.disableVertexAttribArray(program.uv);
    }

/*
Render the scene in an orhtogonal perspective, from the light source, writing
only depth.
*/
    void renderShadow(RenderingContext gl, Camera camera) {
    	gl.bindFramebuffer(FRAMEBUFFER, deferredFBO.shadowFbo);
    	gl.colorMask(false, false, false, false); // It's a depth-pass; no need
    											  // to render colours.
        gl.enable(DEPTH_TEST);
        gl.clear(DEPTH_BUFFER_BIT);
        var program = shaderManager.getProgram("light");
        gl.useProgram(program.handle);

        setModelToCameraMatrix(gl, camera, program.unifs["modelToCam"]);

        gl.enableVertexAttribArray(program.vertex);

        gl.bindBuffer(ARRAY_BUFFER, planeVertexBuffer);
        gl.vertexAttribPointer(program.vertex, 3, FLOAT, false, 0, 0);

        gl.bindBuffer(ELEMENT_ARRAY_BUFFER, planeIndexBuffer);
        gl.drawElements(TRIANGLES, 6, UNSIGNED_SHORT, 0);

		if (models.containsKey("teapot")) {
			Model model = models["teapot"];
			gl.bindBuffer(ARRAY_BUFFER, model.vertexBuffer);
			gl.vertexAttribPointer(program.vertex, 3, FLOAT, false, 0, 0);

			gl.bindBuffer(ELEMENT_ARRAY_BUFFER, model.indexBuffer);
			gl.drawElements(TRIANGLES, model.numIndices, UNSIGNED_SHORT, 0);
		}
		gl.colorMask(true, true, true, true);
		gl.cullFace(BACK);

		gl.disableVertexAttribArray(program.vertex);
    }

/*
Render scene depth, normal, and albedo to textures, before rendering to the
screen (see: renderToScreen()).
*/
    void renderScene(RenderingContext gl, Camera camera, Camera lightCam) {
    	gl.bindFramebuffer(FRAMEBUFFER, deferredFBO.finalFbo);
		gl.disable(DEPTH_TEST);
		gl.clear(COLOR_BUFFER_BIT | DEPTH_BUFFER_BIT);
		renderSky(gl);
        gl.bindFramebuffer(FRAMEBUFFER, deferredFBO.baseFbo);
        gl.enable(DEPTH_TEST);
        gl.clear(COLOR_BUFFER_BIT | DEPTH_BUFFER_BIT);
        var program = shaderManager.getProgram("entity");
        gl.useProgram(program.handle);

        setModelToCameraMatrix(gl, camera, program.unifs["modelToCam"]);

        gl.enableVertexAttribArray(program.vertex);
        gl.enableVertexAttribArray(program.normal);

        gl.bindBuffer(ARRAY_BUFFER, planeVertexBuffer);
        gl.vertexAttribPointer(program.vertex, 3, FLOAT, false, 0, 0);

        gl.bindBuffer(ARRAY_BUFFER, planeNormalBuffer);
        gl.vertexAttribPointer(program.normal, 3, FLOAT, false, 0, 0);

        gl.uniform4f(program.unifs["colour"], 1.0, 1.0, 1.0, 1.0);

        gl.bindBuffer(ELEMENT_ARRAY_BUFFER, planeIndexBuffer);
        gl.drawElements(TRIANGLES, 6, UNSIGNED_SHORT, 0);

		if (models.containsKey("teapot")) {
			Model model = models["teapot"];
			gl.bindBuffer(ARRAY_BUFFER, model.vertexBuffer);
			gl.vertexAttribPointer(program.vertex, 3, FLOAT, false, 0, 0);

			gl.bindBuffer(ARRAY_BUFFER, model.normalBuffer);
			gl.vertexAttribPointer(program.normal, 3, FLOAT, false, 0, 0);

			gl.uniform4f(program.unifs["colour"], 206.0 / 255.0,
			                                      173.0 / 255.0,
			                                      0.0 / 255.0, 1.0);

			gl.bindBuffer(ELEMENT_ARRAY_BUFFER, model.indexBuffer);
			gl.drawElements(TRIANGLES, model.numIndices, UNSIGNED_SHORT, 0);
		}

		gl.disableVertexAttribArray(program.vertex);
        gl.disableVertexAttribArray(program.normal);

		renderToScreen(gl, camera, lightCam);
    }

    void renderSky(RenderingContext gl) {
    	gl.disable(DEPTH_TEST);
    	// gl.disable(CULL_FACE);
    	gl.clear(COLOR_BUFFER_BIT | DEPTH_BUFFER_BIT);
    	var program = shaderManager.getProgram("sky");
    	gl.useProgram(program.handle);

    	gl.enableVertexAttribArray(program.vertex);
        gl.enableVertexAttribArray(program.uv);

    	gl.bindBuffer(ARRAY_BUFFER, screenBuffer);
		gl.vertexAttribPointer(program.vertex, 2, FLOAT, false, 0, 0);
		gl.bindBuffer(ARRAY_BUFFER, screenUVBuffer);
		gl.vertexAttribPointer(program.uv, 2, FLOAT, false, 0, 0);
		gl.bindBuffer(ELEMENT_ARRAY_BUFFER, screenIndexBuffer);
		gl.drawElements(TRIANGLES, 6, UNSIGNED_SHORT, 0);

		gl.disableVertexAttribArray(program.vertex);
        gl.disableVertexAttribArray(program.uv);
    }

    static const int noiseSize = 4;
/*
Noise tex for SSAO. The texture is used for randomly rotating the kernel. For
each fragment, when performing SSAO, the normal direction is the z-axis, hence
why the random vectors of the noise tex have no z-component (the sampling
kernel is rotated about the normal).
*/
    Texture genNoiseTex(RenderingContext gl) {
    	List noise = new List();
    	for (int i = 0; i < noiseSize * noiseSize; i+=1) {
    		Vector3 randVec = new Vector3.zero();
    		randVec.x = rng.nextDouble() * 2.0 - 1.0; // Map to range -1.0, 1.0
    		randVec.y = rng.nextDouble() * 2.0 - 1.0;
    		randVec.z = 0.0;
    		randVec.normalize();
    		noise.add(randVec.x);
    		noise.add(randVec.y);
    		noise.add(randVec.z);
    	}
    	Texture tex = gl.createTexture();
    	gl.bindTexture(TEXTURE_2D, tex);
    	gl.texImage2DTyped(TEXTURE_2D, 0, RGB, noiseSize, noiseSize, 0, RGB,
    					   FLOAT, new Float32List.fromList(noise));
		gl.texParameterf(TEXTURE_2D, TEXTURE_MIN_FILTER, NEAREST);
		gl.texParameterf(TEXTURE_2D, TEXTURE_MAG_FILTER, NEAREST);
		gl.texParameteri(TEXTURE_2D, TEXTURE_WRAP_S, REPEAT);
		gl.texParameteri(TEXTURE_2D, TEXTURE_WRAP_T, REPEAT);

		return tex;
    }

	static const kernelSize = 128;
/*
Rotation kernel for SSAO.
*/
    void genRotationKernel(RenderingContext gl) {
    	List kernel = new List();
    	for (int i = 0; i < kernelSize; i++) {
    		Vector3 randVec = new Vector3.zero();
    		randVec.x = rng.nextDouble() * 2.0 - 1.0; // Range -1.0, 1.0
    		randVec.y = rng.nextDouble() * 2.0 - 1.0;
    		randVec.z = rng.nextDouble(); // Range 0.0 to 1.0, pointing outward.

    		randVec.normalize();

    		// Increase the radius of each subsequent sample
    		var scale = i.toDouble() / kernelSize.toDouble();

    		var weight = scale * scale;
    		scale = 0.1 * (1.0 - weight) + 1.0 * weight;

    		randVec = randVec * 0.1;
    		kernel.add(randVec.x);
    		kernel.add(randVec.y);
    		kernel.add(randVec.z);
    	}

    	var program = shaderManager.getProgram("basic").handle;
    	gl.useProgram(program);
    	gl.uniform3fv(gl.getUniformLocation(program, "kernel"),
    				  new Float32List.fromList(kernel));
    }

    void setSpecularExponent(RenderingContext gl, num value) {
    	var program = shaderManager.getProgram("basic");
    	gl.useProgram(program.handle);
    	gl.uniform1f(program.unifs["specExp"], value.toDouble());
    }

    void setSpecularIntensity(RenderingContext gl, num value) {
    	var program = shaderManager.getProgram("basic");
    	gl.useProgram(program.handle);
    	gl.uniform1f(program.unifs["specInt"], value.toDouble());
    }

    void setRoughness(RenderingContext gl, num value) {
    	var program = shaderManager.getProgram("basic");
    	gl.useProgram(program.handle);
    	gl.uniform1f(program.unifs["roughness"], value.toDouble());
    }

    void setExposure(RenderingContext gl, num value) {
    	var program = shaderManager.getProgram("basic");
    	gl.useProgram(program.handle);
    	gl.uniform1f(program.unifs["exposure"], value.toDouble());
    }

    void setDiffuseIntensity(RenderingContext gl, num value) {
    	var program = shaderManager.getProgram("basic");
    	gl.useProgram(program.handle);
    	gl.uniform1f(program.unifs["diffuseInt"], value.toDouble());
    }
}