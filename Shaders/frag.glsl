#version 430 core
out vec4 FragColor;
in vec2 vertexUV;

uniform sampler2D texture1;

void main() {

    FragColor = vec4(texture(texture1,vertexUV).xyz, 1.0);
}

 




