#version 430 core

//https://gist.github.com/983/e170a24ae8eba2cd174f
vec3 rgb2hsv(vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

struct Fields2D {
    float d;
    float u;
    float v;
    float E;
    float S;
};

struct coordIndexPair {
    int i;
    int j;
    int index;
};

struct DebugThing {
    int f2d;
};

struct DataGroup {
    float center;
    float right;
    float left;
    float up;
    float down;
};

struct DataGroupVec2 {
    vec2 center;
    vec2 right;
    vec2 left;
    vec2 up;
    vec2 down;
};

struct DataGroupVec3 {
    vec3 center;
    vec3 right;
    vec3 left;
    vec3 up;
    vec3 down;
};

struct iDataGroup4 {
    uint right;
    uint left;
    uint up;
    uint down;
};

layout (local_size_x = 1, local_size_y = 1) in;
layout(rgba32f, binding = 1) uniform image2D imgOutput;

layout (std430, binding = 2) buffer shader_data {
    float dx;
    float dy;
    float dt;
    int mouseX;
    int mouseY;
    int screenWidth;
    int screenHeight;
    Fields2D[] fields;
};


layout (std430, binding = 3) buffer out_data {
    Fields2D[] outFields;
};

layout (std430, binding = 4) buffer mesh_data {
    int[] mesh;
};

layout (std430, binding = 5) buffer out_debug {
    DebugThing[] debug;
};

layout (std430, binding = 6) buffer prevData {
    Fields2D[] prevFields;
};

uint coordToIndex(int i, int j) {
    return i*gl_NumWorkGroups.y+j;
}
uint width = gl_NumWorkGroups.x;
uint height = gl_NumWorkGroups.y;
ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
uint index = coordToIndex(coords.x, coords.y);
iDataGroup4 indices = iDataGroup4(coordToIndex(coords.x+1,coords.y),coordToIndex(coords.x-1,coords.y),coordToIndex(coords.x,coords.y+1),coordToIndex(coords.x,coords.y-1));
    int i = coords.x;
    int j = coords.y;

float BC(int valId, int iOffset, int jOffset) {
    uint newIndex = coordToIndex(int(clamp(i+iOffset,0,int(width-1))),int(clamp(j+jOffset,0,int(height-1))));
    bool objectFlag = false;
    if (mesh[newIndex] == 1) {
        newIndex = coordToIndex(i,j);
        objectFlag = true;
    }
    if (objectFlag) {
        switch (valId) {
            case 0:
                return fields[newIndex].d;
            case 1:
                return 0;
            case 2:
                return 0;
            case 3:
                return fields[newIndex].E;
            case 4:
                return fields[newIndex].S;
        }
    } else if (i+iOffset < 0) { 
        switch (valId) {
            //d
            case 0:
                return 1.293;
            //u
            case 1:
                return 0;
            //v
            case 2:
                return 0;  
            //e
            case 3:
                return fields[newIndex].E;
            //S 
            case 4:
                return fields[newIndex].S;
        }
    } else if (i+iOffset >= width) {
        switch (valId) {
            //d
            case 0:
                return fields[newIndex].d;
            //u
            case 1:
                return 0;
            //v
            case 2:
                return 0;
            //e
            case 3:
                return fields[newIndex].E;
            //S 
            case 4:
                return fields[newIndex].S;
        }
    } else if (j+jOffset < 0) {
        switch (valId) {
            //d
            case 0:
                return fields[newIndex].d;
            //u
            case 1:
                return 0;
            //v
            case 2:
                return 0;
            //e
            case 3:
                return fields[newIndex].E;
            //S 
            case 4:
                return fields[newIndex].S;
        }
    } else if (j+jOffset >= height) {
        switch (valId) {
            //d
            case 0:
                return fields[newIndex].d;
            //u
            case 1:
                return 1;
            //v
            case 2:
                return 0;
            //e
            case 3:
                return fields[newIndex].E;
            //S 
            case 4:
                return fields[newIndex].S;
        }
    } else {
        switch (valId) {
            case 0:
                return fields[newIndex].d;
            case 1:
                return fields[newIndex].u;
            case 2:
                return fields[newIndex].v;
            case 3:
                return fields[newIndex].E;
            case 4:
                return fields[newIndex].S;
        }
    }
}

void main() {
    DataGroup T = DataGroup(BC(3,0,0)/0.718,BC(3,1,0)/0.718,BC(3,-1,0)/0.718,BC(3,0,1)/0.718,BC(3,0,-1)/0.718);
    DataGroup p = DataGroup(BC(0,0,0) * 0.286 * T.center, BC(0,1,0) * 0.286 * T.right, BC(0,-1,0) * 0.286 * T.left, BC(0,0,1) * 0.286 * T.up, BC(0,0,-1) * 0.286 * T.down);

    float uDx = (BC(1,1,0) - BC(1,-1,0)) / (2.0*dx);
    float uDy = (BC(1,0,1) - BC(1,0,-1)) / (2.0*dy);
    float vDx = (BC(2,1,0) - BC(2,-1,0)) / (2.0*dx);
    float vDy = (BC(2,0,1) - BC(2,0,-1)) / (2.0*dy);
    float visc1 = 0.0000186;
    float visc2 = visc1;
    float kappa = -0.02662;

    if (mesh[index] == 1) {
        outFields[index].d = 0;
        outFields[index].u = 0;
        outFields[index].v = 0;
        outFields[index].E = 0;
        outFields[index].S = 0;
    } else if (true) {
        outFields[index].d = fields[index].d + dt * (-(fields[index].u >= 0 ? fields[index].d*fields[index].u-BC(0,-1,0)*BC(1,-1,0) : BC(0,1,0)*BC(1,1,0)-fields[index].d*fields[index].u)/dx
         - (fields[index].v >= 0 ? fields[index].d*fields[index].v-BC(0,0,-1)*BC(2,0,-1) : BC(0,0,1)*BC(2,0,1)-fields[index].d*fields[index].v)/dy);
        outFields[index].u = fields[index].u + (1.0 / fields[index].d) * dt * (-(fields[index].u >= 0 ? fields[index].d*fields[index].u*fields[index].u-BC(0,-1,0)*BC(1,-1,0)*BC(1,-1,0) : BC(0,1,0)*BC(1,1,0)*BC(1,1,0) - fields[index].d*fields[index].u*fields[index].u)/dx
         - (fields[index].v >= 0 ? fields[index].d*fields[index].u*fields[index].v - BC(0,0,-1)*BC(1,0,-1)*BC(2,0,-1) : BC(0,0,1)*BC(1,0,1)*BC(2,0,1)-fields[index].d*fields[index].u*fields[index].v)/dy 
         - (p.right-p.left)/(2.0*dx) + visc1 * (2.0*(BC(1,1,0)-2.0*fields[index].u+BC(1,-1,0)/(dx*dx) + (BC(1,0,1)-2.0*fields[index].u+BC(1,0,-1))/(dy*dy) + vDx*vDy)) 
         + visc2 * ((BC(1,1,0)-2.0*fields[index].u+BC(1,-1,0))/(dx*dx) + vDx*vDy));
        outFields[index].v = fields[index].v + (1.0 / fields[index].d) * dt * (-(fields[index].u >= 0 ? fields[index].d*fields[index].u*fields[index].v - BC(0,-1,0)*BC(1,-1,0)*BC(2,-1,0) : BC(0,1,0)*BC(1,1,0)*BC(2,1,0) - fields[index].d*fields[index].u*fields[index].v)/dx 
        - (fields[index].v >= 0 ? fields[index].d*fields[index].v*fields[index].v - BC(0,0,-1)*BC(2,0,-1)*BC(2,0,-1) : BC(0,0,1)*BC(2,0,1)*BC(2,0,1) - fields[index].d*fields[index].v*fields[index].v)/dy
         - (p.up-p.down)/(2.0*dy) + visc1 * ((BC(2,1,0)-2.0*fields[index].v+BC(2,-1,0))/(dx*dx) + 2.0*(BC(2,0,1)-2.0*fields[index].v+BC(2,0,-1))/(dy*dy)+uDx*uDy) + visc2 * ((BC(2,0,1)-2.0*fields[index].v+BC(2,0,-1))/(dy*dy)+uDx*uDy));
        outFields[index].E = fields[index].E + (1.0 / fields[index].d) * dt * (-(fields[index].u >= 0 ? fields[index].d*fields[index].u*fields[index].E - BC(0,-1,0)*BC(1,-1,0)*BC(3,-1,0) : BC(0,1,0)*BC(1,1,0)*BC(3,1,0)-fields[index].d*fields[index].u*fields[index].E)/dx 
        - (fields[index].v >= 0 ? fields[index].d*fields[index].v*fields[index].E - BC(0,0,-1)*BC(2,0,-1)*BC(3,0,-1) : BC(0,0,1)*BC(2,0,1)*BC(3,0,1) - fields[index].d*fields[index].v*fields[index].E)/dy 
        - kappa*((T.right-2.0*T.center+T.left)/(dx*dx)+(T.up-2.0*T.center+T.down)/(dy*dy)) + (uDx+vDy)*(-p.center + visc2*(uDx+vDy)) + visc1 * (2.0*uDx*uDx + 2.0*vDy*vDy + vDx*vDx + uDy*uDy + 2.0*uDy*vDx));
       // outFields[index].S = fields[index].S + (1.0 / fields[index].d) * dt * (-(dXF * uXF * SXF - dXB * uXB * SXB) / dx - (dYF * vYF * SYF - dYB * vYB * SYB) / dy + 0.05*(SDxXF - SDxXB) / dx + 0.05*(SDyYF - SDyYB) / dy);
    } else {
        outFields[index].d = (4.0*fields[index].d-prevFields[index].d + dt * (-(fields[index].u >= 0 ? fields[index].d*fields[index].u-BC(0,-1,0)*BC(1,-1,0) : BC(0,1,0)*BC(1,1,0)-fields[index].d*fields[index].u)/dx
         - (fields[index].v >= 0 ? fields[index].d*fields[index].v-BC(0,0,-1)*BC(2,0,-1) : BC(0,0,1)*BC(2,0,1)-fields[index].d*fields[index].v)/dy))/3.0;
        outFields[index].u = (4.0*fields[index].u-prevFields[index].u + (1.0 / fields[index].d) * dt * (-(fields[index].u >= 0 ? fields[index].d*fields[index].u*fields[index].u-BC(0,-1,0)*BC(1,-1,0)*BC(1,-1,0) : BC(0,1,0)*BC(1,1,0)*BC(1,1,0) - fields[index].d*fields[index].u*fields[index].u)/dx
         - (fields[index].v >= 0 ? fields[index].d*fields[index].u*fields[index].v - BC(0,0,-1)*BC(1,0,-1)*BC(2,0,-1) : BC(0,0,1)*BC(1,0,1)*BC(2,0,1)-fields[index].d*fields[index].u*fields[index].v)/dy 
         - (p.right-p.left)/(2.0*dx) + visc1 * (2.0*(BC(1,1,0)-2.0*fields[index].u+BC(1,-1,0)/(dx*dx) + (BC(1,0,1)-2.0*fields[index].u+BC(1,0,-1))/(dy*dy) + vDx*vDy)) 
         + visc2 * ((BC(1,1,0)-2.0*fields[index].u+BC(1,-1,0))/(dx*dx) + vDx*vDy)))/3.0;
        outFields[index].v = (4.0*fields[index].v-prevFields[index].v + (1.0 / fields[index].d) * dt * (-(fields[index].u >= 0 ? fields[index].d*fields[index].u*fields[index].v - BC(0,-1,0)*BC(1,-1,0)*BC(2,-1,0) : BC(0,1,0)*BC(1,1,0)*BC(2,1,0) - fields[index].d*fields[index].u*fields[index].v)/dx 
        - (fields[index].v >= 0 ? fields[index].d*fields[index].v*fields[index].v - BC(0,0,-1)*BC(2,0,-1)*BC(2,0,-1) : BC(0,0,1)*BC(2,0,1)*BC(2,0,1) - fields[index].d*fields[index].v*fields[index].v)/dy
         - (p.up-p.down)/(2.0*dy) + visc1 * ((BC(2,1,0)-2.0*fields[index].v+BC(2,-1,0))/(dx*dx) + 2.0*(BC(2,0,1)-2.0*fields[index].v+BC(2,0,-1))/(dy*dy)+uDx*uDy) + visc2 * ((BC(2,0,1)-2.0*fields[index].v+BC(2,0,-1))/(dy*dy)+uDx*uDy)))/3.0;
        outFields[index].E = (4.0*fields[index].E-prevFields[index].E + (1.0 / fields[index].d) * dt *(-(fields[index].u >= 0 ? fields[index].d*fields[index].u*fields[index].E - BC(0,-1,0)*BC(1,-1,0)*BC(3,-1,0) : BC(0,1,0)*BC(1,1,0)*BC(3,1,0)-fields[index].d*fields[index].u*fields[index].E)/dx 
        - (fields[index].v >= 0 ? fields[index].d*fields[index].v*fields[index].E - BC(0,0,-1)*BC(2,0,-1)*BC(3,0,-1) : BC(0,0,1)*BC(2,0,1)*BC(3,0,1) - fields[index].d*fields[index].v*fields[index].E)/dy 
        - kappa*((T.right-2.0*T.center+T.left)/(dx*dx)+(T.up-2.0*T.center+T.down)/(dy*dy)) + (uDx+vDy)*(-p.center + visc2*(uDx+vDy)) + visc1 * (2.0*uDx*uDx + 2.0*vDy*vDy + vDx*vDx + uDy*uDy + 2.0*uDy*vDx)))/3.0;
    //    outFields[index].S = fields[index].S + (1.0 / fields[index].d) * dt * (-(dXF * uXF * SXF - dXB * uXB * SXB) / dx - (dYF * vYF * SYF - dYB * vYB * SYB) / dy + 0.05*(SDxXF - SDxXB) / dx + 0.05*(SDyYF - SDyYB) / dy);
    }

    vec3 SVIEW = hsv2rgb(vec3(fields[index].S*0.75,1.0,1.0));
    vec3 sEdVIEW = vec3(sqrt(outFields[index].u*outFields[index].u+outFields[index].v*outFields[index].v)/1.0,outFields[index].E / 5000.0,outFields[index].d/2.5);
    vec3 velocityVIEW = vec3(abs(outFields[index].u/1.0),0,abs(outFields[index].v)/1.0);
    vec3 uVIEW = vec3(fields[index].u/120.0,0,-fields[index].u/4.0);
    vec3 vVIEW = vec3(fields[index].v/10.0,0,-fields[index].v/10.0);

    debug[index].f2d = mesh[index];

    vec3 vorticityVIEW = vec3(vDx-uDy,0,-(vDx-uDy));
    imageStore(imgOutput, coords, vec4(sEdVIEW,1.0));
    if (mesh[index] == 1) {
        imageStore(imgOutput, coords, vec4(uVIEW,0.0));
    }
} 

