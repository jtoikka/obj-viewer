import 'dart:html';
import 'dart:web_gl';
import 'dart:core';

import 'package:game_loop/game_loop_html.dart';
import 'package:vector_math/vector_math.dart';

import 'renderer.dart';
import 'camera.dart';

CanvasElement canvas;
RenderingContext gl;
Renderer renderer;
Camera camera;
Camera lightCamera;

num specularExp = 0;
num specularInt = 0;
num roughness = 0;
num exposure = 0;
num diffuseInt = 0;

Map<int, int> keys = new Map<int, int>();

void updateCanvas(GameLoopHtml gameLoop) {
	renderer.renderShadow(gl, lightCamera);
    renderer.renderScene(gl, camera, lightCamera);

    InputElement specularExponentSlider = querySelector("#specularExponent");
    num specExp = specularExponentSlider.valueAsNumber;
    if (specExp != specularExp) {
        specularExp = specExp;
        renderer.setSpecularExponent(gl, specExp);
    }
    InputElement specularIntensitySlider = querySelector("#specularIntensity");
    num specInt = specularIntensitySlider.valueAsNumber;
    if (specInt != specularInt) {
    	specularInt = specInt;
    	renderer.setSpecularIntensity(gl, specInt);
    }
    InputElement roughnessSlider = querySelector("#roughness");
    num rough = roughnessSlider.valueAsNumber;
    if (rough != roughness) {
    	roughness = rough;
    	renderer.setRoughness(gl, rough);
    }
    InputElement exposureSlider = querySelector("#exposure");
    num exp = exposureSlider.valueAsNumber;
    if (exp != exposure) {
    	exposure = exp;
    	renderer.setExposure(gl, exp);
    }
    InputElement diffuseIntensitySlider = querySelector("#diffuseIntensity");
    num diffInt = diffuseIntensitySlider.valueAsNumber;
    if (diffInt != diffuseInt) {
    	diffuseInt = diffInt;
    	renderer.setDiffuseIntensity(gl, diffInt);
    }
}

void keyDownHandler(KeyboardEvent event) {
    keys[event.keyCode] = event.timeStamp;
}

void keyUpHandler(KeyboardEvent event) {
    keys.remove(event.keyCode);
}

void update(GameLoopHtml gameLoop) {
    if (gameLoop.pointerLock.locked) {
        if (gameLoop.mouse.dx != 0 || gameLoop.mouse.dy != 0) {
            camera.rotate(gameLoop.mouse.dx, gameLoop.mouse.dy);
        }
        double frameTime = gameLoop.updateTimeStep;

        if (gameLoop.keyboard.isDown(KeyCode.W)) {
            camera.moveForward(frameTime * 10.0);
        }
        if (gameLoop.keyboard.isDown(KeyCode.S)) {
            camera.moveBackward(frameTime * 10.0);
        }
        if (gameLoop.keyboard.isDown(KeyCode.A)) {
            camera.moveLeft(frameTime * 10.0);
        }
        if (gameLoop.keyboard.isDown(KeyCode.D)) {
            camera.moveRight(frameTime * 10.0);
        }
    }
}

void main() {
    print("Init canvas");
    canvas = querySelector("#webGLCanvas");
    gl = canvas.getContext("webgl");
    if (gl == null) {
        gl = canvas.getContext("experimental-webgl");
        if (gl == null) {
            return;
        }
    }

    print("Init extensions");
    // Initialize extensions. Most of what is needed will most likely be
    // standard in WebGL 2.0.
    // var extension = gl.getExtension("OES_standard_derivatives");
    // if (extension == null) {
    //     print("Standard derivatives not supported");
    // }
    // extension = gl.getExtension("OES_element_index_uint");
    // if (extension == null) {
    //     print("Index extension not supported");
    // }
    DepthTexture depthTex = gl.getExtension("WEBGL_depth_texture");
    if (depthTex == null) {
        print("Depth texture not supported");
    }
    var extension = gl.getExtension("OES_texture_float");
    if (extension == null) {
        print("Texture float not supported");
    }

    print("Init renderer");
    renderer = new Renderer(gl, canvas.width, canvas.height);
    print("Init camera");
    camera = new Camera();

    // The sun is essentially a camera: useful for shadow mapping.
    lightCamera = new Camera();
    lightCamera.direction = new Vector3(-0.5, -0.7, -1.0);
    lightCamera.direction.normalize();
    lightCamera.location = new Vector3(0.0, 0.0, 0.0);

    GameLoopHtml gameLoop = new GameLoopHtml(canvas);
    gameLoop.onUpdate = update;
    gameLoop.onRender = updateCanvas;
    gameLoop.start();
}