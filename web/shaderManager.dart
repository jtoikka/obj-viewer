library shaderManager;

import 'dart:web_gl';
import 'dart:html';

class ShaderProgram {
	var handle;
	var vertex;
	var normal;
    var uv;
	Map unifs = new Map();
}

class ShaderManager {
    Map programs; // Map of programs, accessed via name

    ShaderManager() {
        programs = new Map();
    }

	void initProgram(RenderingContext gl, String name,
	                 String vertexSrc, String fragSrc) {
        String vertSource = querySelector(vertexSrc).text;
        String fragSource = querySelector(fragSrc).text;

        var vertexShader = gl.createShader(VERTEX_SHADER);
        gl.shaderSource(vertexShader, vertSource);
        gl.compileShader(vertexShader);

        var fragmentShader = gl.createShader(FRAGMENT_SHADER);
        gl.shaderSource(fragmentShader, fragSource);
        gl.compileShader(fragmentShader);

        var program = gl.createProgram();
        gl.attachShader(program, vertexShader);
        gl.attachShader(program, fragmentShader);
        gl.linkProgram(program);

        if (!gl.getShaderParameter(vertexShader, COMPILE_STATUS)) {
            print(gl.getShaderInfoLog(vertexShader));
        }

        if (!gl.getShaderParameter(fragmentShader, COMPILE_STATUS)) {
            print(gl.getShaderInfoLog(fragmentShader));
        }

        if (!gl.getProgramParameter(program, LINK_STATUS)) {
            print(gl.getProgramInfoLog(program));
        }

        gl.deleteShader(vertexShader);
        gl.deleteShader(fragmentShader);

        gl.useProgram(program);

        var vertexLocation = gl.getAttribLocation(program, "position");
        gl.enableVertexAttribArray(vertexLocation);

        ShaderProgram p = new ShaderProgram();
        p.handle = program;
        p.vertex = vertexLocation;

        var uvLocation = gl.getAttribLocation(program, "uv");

        if (uvLocation != -1) {
            gl.enableVertexAttribArray(uvLocation);
            p.uv = uvLocation;
        }

        var normalLocation = gl.getAttribLocation(program, "normal");

        if (normalLocation != -1) {
            gl.enableVertexAttribArray(normalLocation);
            p.normal = normalLocation;
        }

        programs[name] = p;
    }

	void attachTexture(RenderingContext gl, String programName,
	                   String texName, int num) {
	    var program = programs[programName];
	    gl.useProgram(program.handle);
	    var texUnif = gl.getUniformLocation(program.handle, texName);
	    gl.uniform1i(texUnif, num);
	}

	ShaderProgram getProgram(String id) {
        return programs[id];
    }
}