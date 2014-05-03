library camera;

import 'package:vector_math/vector_math.dart';

class Camera {
	Vector3 direction;
	Vector3 up;
	Vector3 location;

	Camera() {
		direction = new Vector3(0.5, -1.0, -1.0);
		direction.normalize();
		up = new Vector3(0.0, 1.0, 0.0);
		location = new Vector3(-10.0, 22.0, 18.0);
	}

	Matrix4 getLookMatrix() {
		return makeViewMatrix(location, location + direction, up);
	}

	void moveForward(double amount) {
		location += direction * amount;
	}

	void moveBackward(double amount) {
		location -= direction * amount;
	}

	void moveLeft(double amount) {
		location += up.cross(direction) * amount;
	}

	void moveRight(double amount) {
	    location += direction.cross(up) * amount;
	}

	void rotate(int x, int y) {
	    double xDeg = x / 300.0;
	    double yDeg = -y / 300.0;

	    var rotationMatrix = new Matrix4.rotationY(xDeg);
	    direction = (rotationMatrix *
                       new Vector4(direction.x,
                                   direction.y,
                                   direction.z, 1.0)).xyz;

	    var axis = direction.cross(up);

	    rotationMatrix = new Matrix4.identity().rotate(axis, yDeg);
	    direction = (rotationMatrix *
                               new Vector4(direction.x,
                                           direction.y,
                                           direction.z, 1.0)).xyz;
	}

	void rotateAboutY(int amount) {
	    var rotationMatrix = new Matrix4.rotationY(amount / 300);
		direction = (rotationMatrix *
		             new Vector4(direction.x,
		                         direction.y,
		                         direction.z, 1.0)).xyz;
	}

	void rotateAboutX(int amount) {
            var rotationMatrix = new Matrix4.rotationX(-amount / 300);
            direction = (rotationMatrix *
                         new Vector4(direction.x,
                                     direction.y,
                                     direction.z, 1.0)).xyz;
        }
}