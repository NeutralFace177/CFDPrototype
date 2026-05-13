#version 430 core

layout (local_size_x = 1, local_size_y = 1) in;
layout(rgba32f, binding = 1) uniform image2D imgOutput;

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
    Fields2D f2d;
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

//layout (std430, binding = 5) buffer out_debug {
//    DebugThing[] debug;
//};

uint coordToIndex(int i, int j) {
    return i*gl_NumWorkGroups.y+j;
}
uint width = gl_NumWorkGroups.x;
uint height = gl_NumWorkGroups.y;
ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
uint index = coordToIndex(coords.x, coords.y);
iDataGroup4 indices = iDataGroup4(coordToIndex(coords.x+1,coords.y),coordToIndex(coords.x-1,coords.y),coordToIndex(coords.x,coords.y+1),coordToIndex(coords.x,coords.y-1));

float BC(int valId, int i, int j, int iOffset, int jOffset) {
    uint newIndex = coordToIndex(int(clamp(i+iOffset,0,int(width-1))),int(clamp(j+jOffset,0,int(height-1))));
    if (i+iOffset < 0) { 
        switch (valId) {
            //d
            case 0:
                return 1.293;
            //u
            case 1:
                return 5;
            //v
            case 2:
                return 0;  
            //e
            case 3:
                return 0.718 * 30.0 + 0.5 * (5*5);
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
                return fields[newIndex].u;
            //v
            case 2:
                return fields[newIndex].v;
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
                return 5;
            //v
            case 2:
                return 0;
            //e
            case 3:
                return fields[newIndex].E - 0.5 * (fields[newIndex].u*fields[newIndex].u+fields[newIndex].v*fields[newIndex].v) + 0.5 * (5*5);
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
                return 5;
            //v
            case 2:
                return 0;
            //e
            case 3:
                return fields[newIndex].E - 0.5 * (fields[newIndex].u*fields[newIndex].u+fields[newIndex].v*fields[newIndex].v) + 0.5 * (5*5);
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

vec3 calcStressTensor(int i, int j) {
    uint newIndex = coordToIndex(i,j);
    iDataGroup4 newIndices = iDataGroup4(coordToIndex(i+1,j),coordToIndex(i-1,j),coordToIndex(i,j+1),coordToIndex(i,j-1));
    float uDx = 0;
    float uDy = 0;
    float vDx = 0;
    float vDy = 0;
    if (i<0 || i >= width || j < 0 || j >= height) {
        uDx = (BC(1,i,j,0,0) < 0) ? (BC(1,i,j,1,0) - BC(1,i,j,0,0)) / dx : (BC(1,i,j,0,0) - BC(1,i,j,-1,0)) / dx;
        uDy = (BC(2,i,j,0,0) < 0) ? (BC(1,i,j,0,1) - BC(1,i,j,0,0)) / dy : (BC(1,i,j,0,0) - BC(1,i,j,0,-1)) / dy;
        vDx = (BC(1,i,j,0,0) < 0) ? (BC(2,i,j,1,0) - BC(2,i,j,0,0)) / dx : (BC(2,i,j,0,0) - BC(2,i,j,-1,0)) / dx;
        vDy = (BC(2,i,j,0,0) < 0) ? (BC(2,i,j,0,1) - BC(2,i,j,0,0)) / dy : (BC(2,i,j,0,0) - BC(2,i,j,0,-1)) / dy; 
    } else if (i==0 || i == width-1 || j == 0 || j == height-1) {
        uDx = (fields[newIndex].u < 0) ? (BC(1,i,j,1,0) - fields[newIndex].u) / dx : (fields[newIndex].u - BC(1,i,j,-1,0)) / dx;
        uDy = (fields[newIndex].v < 0) ? (BC(1,i,j,0,1) - fields[newIndex].u) / dy : (fields[newIndex].u - BC(1,i,j,0,-1)) / dy;
        vDx = (fields[newIndex].u < 0) ? (BC(2,i,j,1,0) - fields[newIndex].v) / dx : (fields[newIndex].v - BC(2,i,j,-1,0)) / dx;
        vDy = (fields[newIndex].v < 0) ? (BC(2,i,j,0,1) - fields[newIndex].v) / dy : (fields[newIndex].v - BC(2,i,j,0,-1)) / dy; 
    } else {
        uDx = (fields[newIndex].u < 0) ? (fields[newIndices.right].u - fields[newIndex].u) / dx : (fields[newIndex].u - fields[newIndices.left].u) / dx;
        uDy = (fields[newIndex].v < 0) ? (fields[newIndices.up].u - fields[newIndex].u) / dy : (fields[newIndex].u - fields[newIndices.down].u) / dy;
        vDx = (fields[newIndex].u < 0) ? (fields[newIndices.right].v - fields[newIndex].v) / dx : (fields[newIndex].v - fields[newIndices.left].v) / dx;
        vDy = (fields[newIndex].v < 0) ? (fields[newIndices.up].v - fields[newIndex].v) / dy : (fields[newIndex].v - fields[newIndices.down].v) / dy;
    }
    float divU = uDx + vDy;
    float visc = 0.0000186;
    float visc2 = (2.0/2.0) * visc;
    //Txx Txy Tyy
    return vec3(visc2 * divU+2.0*visc*uDx, visc*(uDy+vDx), visc2*divU + 2.0*visc*vDy);
}
//velocity derivatives
vec4 Dv(int i, int j) {
    uint newIndex = coordToIndex(i,j);
    iDataGroup4 newIndices = iDataGroup4(coordToIndex(i+1,j),coordToIndex(i-1,j),coordToIndex(i,j+1),coordToIndex(i,j-1));
    float uDx = 0;
    float uDy = 0;
    float vDx = 0;
    float vDy = 0;
    if (i<0 || i >= width || j < 0 || j >= height) {
        uDx = (BC(1,i,j,0,0) < 0) ? (BC(1,i,j,1,0) - BC(1,i,j,0,0)) / dx : (BC(1,i,j,0,0) - BC(1,i,j,-1,0)) / dx;
        uDy = (BC(2,i,j,0,0) < 0) ? (BC(1,i,j,0,1) - BC(1,i,j,0,0)) / dy : (BC(1,i,j,0,0) - BC(1,i,j,0,-1)) / dy;
        vDx = (BC(1,i,j,0,0) < 0) ? (BC(2,i,j,1,0) - BC(2,i,j,0,0)) / dx : (BC(2,i,j,0,0) - BC(2,i,j,-1,0)) / dx;
        vDy = (BC(2,i,j,0,0) < 0) ? (BC(2,i,j,0,1) - BC(2,i,j,0,0)) / dy : (BC(2,i,j,0,0) - BC(2,i,j,0,-1)) / dy; 
    } else if (i==0 || i == width-1 || j == 0 || j == height-1) {
        uDx = (fields[newIndex].u < 0) ? (BC(1,i,j,1,0) - fields[newIndex].u) / dx : (fields[newIndex].u - BC(1,i,j,-1,0)) / dx;
        uDy = (fields[newIndex].v < 0) ? (BC(1,i,j,0,1) - fields[newIndex].u) / dy : (fields[newIndex].u - BC(1,i,j,0,-1)) / dy;
        vDx = (fields[newIndex].u < 0) ? (BC(2,i,j,1,0) - fields[newIndex].v) / dx : (fields[newIndex].v - BC(2,i,j,-1,0)) / dx;
        vDy = (fields[newIndex].v < 0) ? (BC(2,i,j,0,1) - fields[newIndex].v) / dy : (fields[newIndex].v - BC(2,i,j,0,-1)) / dy; 
    } else {
        uDx = (fields[newIndex].u < 0) ? (fields[newIndices.right].u - fields[newIndex].u) / dx : (fields[newIndex].u - fields[newIndices.left].u) / dx;
        uDy = (fields[newIndex].v < 0) ? (fields[newIndices.up].u - fields[newIndex].u) / dy : (fields[newIndex].u - fields[newIndices.down].u) / dy;
        vDx = (fields[newIndex].u < 0) ? (fields[newIndices.right].v - fields[newIndex].v) / dx : (fields[newIndex].v - fields[newIndices.left].v) / dx;
        vDy = (fields[newIndex].v < 0) ? (fields[newIndices.up].v - fields[newIndex].v) / dy : (fields[newIndex].v - fields[newIndices.down].v) / dy;
    }
    return vec4(uDx,uDy,vDx,vDy);
}

float calcPressure(int i, int j) {
    if (i < 0 || i >= width || j < 0 || j >= height) {
        return BC(0,i,j,0,0) * 0.286 * ((BC(3,i,j,0,0)-0.5*(BC(1,i,j,0,0)*BC(1,i,j,0,0)+BC(2,i,j,0,0)*BC(2,i,j,0,0)))/0.718);
    } else {
        Fields2D values = fields[coordToIndex(i,j)];
        return values.d * 0.286 * ((values.E-0.5*(values.u*values.u+values.v*values.v))/0.718);
    }
}

vec2 calcHeatFlux(int i, int j) {
    float TDx;
    float TDy;
    uint newIndex = coordToIndex(i,j);
    iDataGroup4 newIndices = iDataGroup4(coordToIndex(i+1,j),coordToIndex(i-1,j),coordToIndex(i,j+1),coordToIndex(i,j-1));
    float tmp; //temp temp (like temperary temperature)
    if (i < 0 || i >= width || j < 0 || j >= height) {
        tmp = (BC(3,i,j,0,0)-0.5*(BC(1,i,j,0,0)*BC(1,i,j,0,0)+BC(2,i,j,0,0)*BC(2,i,j,0,0)))/0.718;
        TDx = (BC(1,i,j,0,0) < 0) ? (((BC(3,i,j,1,0)-0.5*(BC(1,i,j,1,0)*BC(1,i,j,1,0)+BC(2,i,j,1,0)*BC(2,i,j,1,0)))/0.718)-tmp) / dx : (tmp - ((BC(3,i,j,-1,0)-0.5*(BC(1,i,j,-1,0)*BC(1,i,j,-1,0)+BC(2,i,j,-1,0)*BC(2,i,j,-1,0)))/0.718)) / dx;
        TDy = (BC(2,i,j,0,0) < 0) ? (((BC(3,i,j,0,1)-0.5*(BC(1,i,j,0,1)*BC(1,i,j,0,1)+BC(2,i,j,0,1)*BC(2,i,j,0,1)))/0.718)-tmp) / dy : (tmp - ((BC(3,i,j,0,-1)-0.5*(BC(1,i,j,0,-1)*BC(1,i,j,0,-1)+BC(2,i,j,0,-1)*BC(2,i,j,0,-1)))/0.718)) / dy;
    } else if (i==0 || i == width-1 || j == 0 || j == height-1) {
        tmp = (fields[newIndex].E-0.5*(fields[newIndex].u*fields[newIndex].u+fields[newIndex].v*fields[newIndex].v))/0.718;
        TDx = (fields[newIndex].u < 0) ? (((BC(3,i,j,1,0)-0.5*(BC(1,i,j,1,0)*BC(1,i,j,1,0)+BC(2,i,j,1,0)*BC(2,i,j,1,0)))/0.718)-tmp) / dx : (tmp - ((BC(3,i,j,-1,0)-0.5*(BC(1,i,j,-1,0)*BC(1,i,j,-1,0)+BC(2,i,j,-1,0)*BC(2,i,j,-1,0)))/0.718)) / dx;
        TDy = (fields[newIndex].v < 0) ? (((BC(3,i,j,0,1)-0.5*(BC(1,i,j,0,1)*BC(1,i,j,0,1)+BC(2,i,j,0,1)*BC(2,i,j,0,1)))/0.718)-tmp) / dy : (tmp - ((BC(3,i,j,0,-1)-0.5*(BC(1,i,j,0,-1)*BC(1,i,j,0,-1)+BC(2,i,j,0,-1)*BC(2,i,j,0,-1)))/0.718)) / dy;
    } else {
        tmp = (fields[newIndex].E-0.5*(fields[newIndex].u*fields[newIndex].u+fields[newIndex].v*fields[newIndex].v))/0.718;
        TDx = (fields[newIndex].u < 0) ? (((fields[newIndices.right].E-0.5*(fields[newIndices.right].u*fields[newIndices.right].u+fields[newIndices.right].v*fields[newIndices.right].v))/0.718) - tmp) / dx : (tmp - ((fields[newIndices.left].E-0.5*(fields       [newIndices.left].u*fields[newIndices.left].u+fields[newIndices.left].v*fields[newIndices.left].v))/0.718)) / dx;
        TDy = (fields[newIndex].v < 0) ? (((fields[newIndices.up].E-0.5*(fields[newIndices.up].u*fields[newIndices.up].u+fields[newIndices.up].v*fields[newIndices.up].v))/0.718) - tmp) / dy : (tmp - ((fields[newIndices.down].E-0.5*(fields[newIndices.down].u*fields[newIndices.down].u+fields[newIndices.down].v*fields[newIndices.down].v))/0.718)) / dy;
    }
    return vec2(-0.02662 * TDx, -0.02662 * TDy);
}

vec2 calcSGradient(int i, int j ) {
    float SDx;
    float SDy;
    uint newIndex = coordToIndex(i,j);
    iDataGroup4 newIndices = iDataGroup4(coordToIndex(i+1,j),coordToIndex(i-1,j),coordToIndex(i,j+1),coordToIndex(i,j-1));
    if (i < 0 || i >= width || j < 0 || j >= height) {
        SDx = (BC(1,i,j,0,0) < 0) ? (BC(4,i,j,1,0) - BC(4,i,j,0,0)) / dx : (BC(4,i,j,0,0)-BC(4,i,j,-1,0)) / dx;
        SDy = (BC(2,i,j,0,0) < 0) ? (BC(4,i,j,0,1) - BC(4,i,j,0,0)) / dy : (BC(4,i,j,0,0)-BC(4,i,j,0,-1)) / dy;
    } else if (i == 0 || i == width-1 || j == 0 || j == height-1) {
        SDx = (fields[newIndex].u < 0) ? (BC(4,i,j,1,0) - fields[newIndex].S) / dx : (fields[newIndex].S-BC(4,i,j,-1,0)) / dx;
        SDy = (fields[newIndex].u < 0) ? (BC(4,i,j,0,1) - fields[newIndex].S) / dy : (fields[newIndex].S-BC(4,i,j,0,-1)) / dy;
    } else {
        SDx = (fields[newIndex].u < 0) ? (fields[newIndices.right].S - fields[newIndex].S) / dx : (fields[newIndex].S-fields[newIndices.left].S) / dx;
        SDy = (fields[newIndex].u < 0) ? (fields[newIndices.up].S - fields[newIndex].S) / dy : (fields[newIndex].S-fields[newIndices.down].S) / dy;
    }
    return vec2(SDx, SDy);
}

float CD(int valId, int dim, bool forwards) {
    int i = coords.x;
    int j = coords.y;
    if (dim == 0) {
        switch (valId) {
            case 0:
                return (fields[index].d+BC(0,i,j,forwards?1:-1,0))/2.0;
            case 1:
                return (fields[index].u+BC(1,i,j,forwards?1:-1,0))/2.0;
            case 2:
                return (fields[index].v+BC(2,i,j,forwards?1:-1,0))/2.0;
            case 3:
                return (fields[index].E+BC(3,i,j,forwards?1:-1,0))/2.0;
            case 4:
                return (fields[index].S+BC(4,i,j,forwards?1:-1,0))/2.0;
        }
    } else {
        switch (valId) {
            case 0:
                return (fields[index].d+BC(0,i,j,0,forwards?1:-1))/2.0;
            case 1:
                return (fields[index].u+BC(1,i,j,0,forwards?1:-1))/2.0;
            case 2:
                return (fields[index].v+BC(2,i,j,0,forwards?1:-1))/2.0;
            case 3:
                return (fields[index].E+BC(3,i,j,0,forwards?1:-1))/2.0;
            case 4:
                return (fields[index].S+BC(4,i,j,0,forwards?1:-1))/2.0;
        }
    }
}

float QUICK(int valId, int dim, bool forwards) {
    int i = coords.x;
    int j = coords.y;
    if (dim == 0) {
        switch (valId) {
            case 0:
                return (fields[index].u >= 0) ? -0.125*BC(0,i,j,forwards?-1:-2,0)+0.75*BC(0,i,j,forwards?0:1,0)+0.375*BC(0,i,j,forwards?1:0,0) : 0.375*BC(0,i,j,forwards?0:-1,0)+0.75*BC(0,i,j,forwards?1:0,0)-0.125*BC(0,i,j,forwards?2:1,0);
            case 1:
                return (fields[index].u >= 0) ? -0.125*BC(1,i,j,forwards?-1:-2,0)+0.75*BC(1,i,j,forwards?0:1,0)+0.375*BC(1,i,j,forwards?1:0,0) : 0.375*BC(1,i,j,forwards?0:-1,0)+0.75*BC(1,i,j,forwards?1:0,0)-0.125*BC(1,i,j,forwards?2:1,0);
            case 2:
                return (fields[index].u >= 0) ? -0.125*BC(2,i,j,forwards?-1:-2,0)+0.75*BC(2,i,j,forwards?0:1,0)+0.375*BC(2,i,j,forwards?1:0,0) : 0.375*BC(2,i,j,forwards?0:-1,0)+0.75*BC(2,i,j,forwards?1:0,0)-0.125*BC(2,i,j,forwards?2:1,0);
            case 3:
                return (fields[index].u >= 0) ? -0.125*BC(3,i,j,forwards?-1:-2,0)+0.75*BC(3,i,j,forwards?0:1,0)+0.375*BC(3,i,j,forwards?1:0,0) : 0.375*BC(3,i,j,forwards?0:-1,0)+0.75*BC(3,i,j,forwards?1:0,0)-0.125*BC(3,i,j,forwards?2:1,0);
            case 4:
                return (fields[index].u >= 0) ? -0.125*BC(4,i,j,forwards?-1:-2,0)+0.75*BC(4,i,j,forwards?0:1,0)+0.375*BC(4,i,j,forwards?1:0,0) : 0.375*BC(4,i,j,forwards?0:-1,0)+0.75*BC(4,i,j,forwards?1:0,0)-0.125*BC(4,i,j,forwards?2:1,0);
        }
    } else {
        switch (valId) {
            case 0:
                return (fields[index].v >= 0) ? -0.125*BC(0,i,j,0,forwards?-1:-2)+0.75*BC(0,i,j,0,forwards?0:1)+0.375*BC(0,i,j,0,forwards?1:0) : 0.375*BC(0,i,j,0,forwards?0:-1)+0.75*BC(0,i,j,0,forwards?1:0)-0.125*BC(0,i,j,0,forwards?2:1);
            case 1:
                return (fields[index].v >= 0) ? -0.125*BC(1,i,j,0,forwards?-1:-2)+0.75*BC(1,i,j,0,forwards?0:1)+0.375*BC(1,i,j,0,forwards?1:0) : 0.375*BC(1,i,j,0,forwards?0:-1)+0.75*BC(1,i,j,0,forwards?1:0)-0.125*BC(1,i,j,0,forwards?2:1);
            case 2:
                return (fields[index].v >= 0) ? -0.125*BC(2,i,j,0,forwards?-1:-2)+0.75*BC(2,i,j,0,forwards?0:1)+0.375*BC(2,i,j,0,forwards?1:0) : 0.375*BC(2,i,j,0,forwards?0:-1)+0.75*BC(2,i,j,0,forwards?1:0)-0.125*BC(2,i,j,0,forwards?2:1);
            case 3:
                return (fields[index].v >= 0) ? -0.125*BC(3,i,j,0,forwards?-1:-2)+0.75*BC(3,i,j,0,forwards?0:1)+0.375*BC(3,i,j,0,forwards?1:0) : 0.375*BC(3,i,j,0,forwards?0:-1)+0.75*BC(3,i,j,0,forwards?1:0)-0.125*BC(3,i,j,0,forwards?2:1);
            case 4:
                return (fields[index].v >= 0) ? -0.125*BC(4,i,j,0,forwards?-1:-2)+0.75*BC(4,i,j,0,forwards?0:1)+0.375*BC(4,i,j,0,forwards?1:0) : 0.375*BC(4,i,j,0,forwards?0:-1)+0.75*BC(4,i,j,0,forwards?1:0)-0.125*BC(4,i,j,0,forwards?2:1);
        }
    }
}

float FOU(int valId, int dim, bool forwards) {
    if (dim == 0) {
        switch (valId) {
            case 0:
                return fields[index].u >= 0 ? (forwards ? fields[index].d : BC(0,coords.x,coords.y,-1,0)) : (forwards ? BC(0,coords.x,coords.y,1,0) : fields[index].d);
            case 1:
                return fields[index].u >= 0 ? (forwards ? fields[index].u : BC(1,coords.x,coords.y,-1,0)) : (forwards ? BC(1,coords.x,coords.y,1,0) : fields[index].u);
            case 2:
                return fields[index].u >= 0 ? (forwards ? fields[index].v : BC(2,coords.x,coords.y,-1,0)) : (forwards ? BC(2,coords.x,coords.y,1,0) : fields[index].v);
            case 3:
                return fields[index].u >= 0 ? (forwards ? fields[index].E : BC(3,coords.x,coords.y,-1,0)) : (forwards ? BC(3,coords.x,coords.y,1,0) : fields[index].E);
            case 4:
                return fields[index].u >= 0 ? (forwards ? fields[index].S : BC(4,coords.x,coords.y,-1,0)) : (forwards ? BC(4,coords.x,coords.y,1,0) : fields[index].S);
        }
    } else {
        switch (valId) {
            case 0:
                return fields[index].v >= 0 ? (forwards ? fields[index].d : BC(0,coords.x,coords.y,0,-1)) : (forwards ? BC(0,coords.x,coords.y,0,1) : fields[index].d);
            case 1:
                return fields[index].v >= 0 ? (forwards ? fields[index].u : BC(1,coords.x,coords.y,0,-1)) : (forwards ? BC(1,coords.x,coords.y,0,1) : fields[index].u);
            case 2:
                return fields[index].v >= 0 ? (forwards ? fields[index].v : BC(2,coords.x,coords.y,0,-1)) : (forwards ? BC(2,coords.x,coords.y,0,1) : fields[index].v);
            case 3:
                return fields[index].v >= 0 ? (forwards ? fields[index].E : BC(3,coords.x,coords.y,0,-1)) : (forwards ? BC(3,coords.x,coords.y,0,1) : fields[index].E);
            case 4:
                return fields[index].v >= 0 ? (forwards ? fields[index].S : BC(4,coords.x,coords.y,0,-1)) : (forwards ? BC(4,coords.x,coords.y,0,1) : fields[index].S);
        }
    }
}

float vanLeer(float r) {
    return (r+abs(r))/(1.0+abs(r));
}

float QUICKLIM(int valId, int dim, bool forwards) {
    int i = int(coords.x);
    int j = int(coords.y);
    float FL = FOU(valId, dim, forwards);
    float FH = QUICK(valId, dim, forwards);
    float r;
    if (dim==0) {
        switch (valId) {
            case 0:
                r = (fields[index].d-BC(0,i,j,-1,0))/(BC(0,i,j,1,0)-fields[index].d+0.0001);
                break;
            case 1:
                r = (fields[index].u-BC(1,i,j,-1,0))/(BC(1,i,j,1,0)-fields[index].u+0.0001);
                break;
            case 2:
                r = (fields[index].v-BC(2,i,j,-1,0))/(BC(2,i,j,1,0)-fields[index].v+0.0001);
                break;
            case 3:
                r = (fields[index].E-BC(3,i,j,-1,0))/(BC(3,i,j,1,0)-fields[index].E+0.0001);
                break;
            case 4:
                r = (fields[index].S-BC(4,i,j,-1,0))/(BC(4,i,j,1,0)-fields[index].S+0.0001);
                break;
        }
    } else {
        switch (valId) {
            case 0:
                r = (fields[index].d-BC(0,i,j,0,-1))/(BC(0,i,j,0,1)-fields[index].d+0.0001);
                break;
            case 1:
                r = (fields[index].u-BC(1,i,j,0,-1))/(BC(1,i,j,0,1)-fields[index].u+0.0001);
                break;
            case 2:
                r = (fields[index].v-BC(2,i,j,0,-1))/(BC(2,i,j,0,1)-fields[index].v+0.0001);
                break;
            case 3:
                r = (fields[index].E-BC(3,i,j,0,-1))/(BC(3,i,j,0,1)-fields[index].E+0.0001);
                break;
            case 4:
                r = (fields[index].S-BC(4,i,j,0,-1))/(BC(4,i,j,0,1)-fields[index].S+0.0001);
                break;
        }
    }
    return FL+vanLeer(r)*(FH-FL);
}

float Scheme(int valId, int dim, bool forwards) {
    return FOU(valId,dim,forwards);
}


void main() {
    DataGroupVec3 tensor = DataGroupVec3(calcStressTensor(coords.x,coords.y),calcStressTensor(coords.x+1,coords.y),calcStressTensor(coords.x-1,coords.y),calcStressTensor(coords.x,coords.y+1),calcStressTensor(coords.x,coords.y-1));
    DataGroupVec2 q = DataGroupVec2(calcHeatFlux(coords.x,coords.y),calcHeatFlux(coords.x+1,coords.y),calcHeatFlux(coords.x-1,coords.y),calcHeatFlux(coords.x,coords.y+1),calcHeatFlux(coords.x,coords.y-1));
    DataGroup p = DataGroup(calcPressure(coords.x,coords.y),calcPressure(coords.x+1,coords.y),calcPressure(coords.x-1,coords.y),calcPressure(coords.x,coords.y+1),calcPressure(coords.x,coords.y-1));
    DataGroupVec2 SGrad = DataGroupVec2(calcSGradient(coords.x,coords.y),calcSGradient(coords.x+1,coords.y),calcSGradient(coords.x-1,coords.y),calcSGradient(coords.x,coords.y+1),calcSGradient(coords.x,coords.y-1));


    float TxxXF = (tensor.center.x + tensor.right.x)/2.0;
    float TxxXB = (tensor.center.x + tensor.left.x)/2.0;

    float TxyXF = (tensor.center.y + tensor.right.y)/2.0;
    float TxyXB = (tensor.center.y + tensor.left.y)/2.0;
    float TxyYF = (tensor.center.y + tensor.up.y)/2.0;
    float TxyYB = (tensor.center.y + tensor.down.y)/2.0;

    float TyyYF = (tensor.center.z + tensor.up.z)/2.0;
    float TyyYB = (tensor.center.z + tensor.down.z)/2.0;

    float pXFC = (p.center + p.right)/2.0;
    float pXBC = (p.center + p.left)/2.0;
    float pYFC = (p.center + p.up)/2.0;
    float pYBC = (p.center + p.down)/2.0;

    float qxXF = (q.center.x + q.right.x)/2.0;
    float qxXB = (q.center.x + q.left.x)/2.0;
    float qyYF = (q.center.y + q.up.y)/2.0;
    float qyYB = (q.center.y + q.down.y)/2.0;

    float dXF = Scheme(0,0,true);
    float dXB = Scheme(0,0,false);
    float dYF = Scheme(0,1,true);
    float dYB = Scheme(0,1,false);

    //Rhie Chow
    float RCXF = 0.5 * (dt/dXF)*((p.right-p.center)/dx);
    float RCXB = 0.5 * (dt/dXB)*((p.center-p.left)/dx);
    float RCYF = 0.5 * (dt/dYF)*((p.up-p.center)/dx);
    float RCYB = 0.5 * (dt/dYB)*((p.center-p.down)/dx);

    float uXF = Scheme(1,0,true) - RCXF;
    float uXB = Scheme(1,0,false) - RCXB;
    float uYF = Scheme(1,1,true) - RCYF;
    float uYB = Scheme(1,1,false) - RCYB;

    float uXFC = CD(1,0,true);
    float uXBC = CD(1,0,false);
    float uYFC = CD(1,1,true);
    float uYBC = CD(1,1,false);

    float vXF = Scheme(2,0,true) - RCXF;
    float vXB = Scheme(2,0,false) - RCXB;
    float vYF = Scheme(2,1,true) - RCYF;
    float vYB = Scheme(2,1,false) - RCYB;

    float vXFC = CD(2,0,true);
    float vXBC = CD(2,0,false);
    float vYFC = CD(2,1,true);
    float vYBC = CD(2,1,false);

    float EXF = Scheme(3,0,true);
    float EXB = Scheme(3,0,false);
    float EYF = Scheme(3,1,true);
    float EYB = Scheme(3,1,false);

    float SXF = Scheme(4,0,true);
    float SXB = Scheme(4,0,false);
    float SYF = Scheme(4,1,true);
    float SYB = Scheme(4,1,false);

    float SDxXF = (SGrad.center.x + SGrad.right.x)/2.0;
    float SDxXB = (SGrad.center.x + SGrad.left.x)/2.0;
    float SDyYF = (SGrad.center.y + SGrad.up.y)/2.0;
    float SDyYB = (SGrad.center.y + SGrad.down.y)/2.0;

    float pressureToggle = 0.0;

    if ((coords.x-0.25*width)*(coords.x-0.25*width)+(3*(coords.y-0.5*height))*(3*(coords.y-0.5*height)) < (width*1.0/30.0)*(width*1.0/10.0) && true) {
        outFields[index].d = fields[index].d;
        outFields[index].u = 0;
        outFields[index].v = 0;
        outFields[index].E = fields[index].E;
        outFields[index].S = fields[index].S;
    } else {
    outFields[index].d = fields[index].d + dt * (-(dXF * uXF - dXB * uXB) / dx - (dYF * vYF - dYB * vYB) / dy);
    outFields[index].u = fields[index].u + (1.0 / fields[index].d) * dt * (-((dXF * uXF * uXF + pressureToggle * pXFC) - (dXB * uXB * uXB + pressureToggle * pXBC)) / dx -
                        (dYF * uYF * vYF - dYB * uYB * vYB) / dy + (TxxXF - TxxXB) / dx + (TxyYF - TxyYB) / dy);
    outFields[index].v = fields[index].v + (1.0 / fields[index].d) * dt * (-(dXF * uXF * vXF - dXB * uXB * vXB) / dx
                        - ((dYF * vYF * vYF + pressureToggle * pYFC) - (dYB * vYB * vYB + pressureToggle * pYBC)) / dy 
                        + (TxyXF - TxyXB) / dx + (TyyYF - TyyYB) / dy);
    outFields[index].E = fields[index].E + (1.0 / fields[index].d) * dt * (-(uXF * (dXF * EXF + pressureToggle * pXFC) - uXB * (dXB * EXB + pressureToggle * pXBC)) / dx
                     - (vYF * (dYF * EYF + pressureToggle * pYFC) - vYB * (dYB * EYB + pressureToggle * pYBC)) / dy
                     +((uXFC * TxxXF + vXFC * TxyXF - qxXF) - (uXBC * TxxXB + vXBC * TxyXB - qxXB)) / dx
                     + ((uYFC * TxyYF + vYFC * TyyYF - qyYF) - (uYBC * TxyYB + vYBC * TyyYB - qyYB)) / dy);
    outFields[index].S = fields[index].S + (1.0 / fields[index].d) * dt * (-(dXF * uXF * SXF - dXB * uXB * SXB) / dx - (dYF * vYF * SYF - dYB * vYB * SYB) / dy + 0.05*(SDxXF - SDxXB) / dx + 0.05*(SDyYF - SDyYB) / dy);
    }

    vec3 SVIEW = hsv2rgb(vec3(fields[index].S*0.75,1.0,1.0));
    vec3 sEdVIEW = vec3(sqrt(fields[index].u*fields[index].u+fields[index].v*fields[index].v),fields[index].E / 50.0,fields[index].d/2.0);
    vec3 velocityVIEW = vec3(fields[index].u/8.0,0,mesh[index]);
    vec3 uVIEW = vec3(fields[index].u/32.0,0,-fields[index].u/1.5);
    vec3 vVIEW = vec3(fields[index].v/1.5,0,-fields[index].v/1.5);

    ///TODO: IMPROVE VORTICITY CALCULATIONS TS LOWK LAZY AND UNOPTIMIZED
    vec4 DV = Dv(coords.x,coords.y);
    vec3 vorticityVIEW = vec3(DV.z-DV.y,0,-(DV.z-DV.y));
    imageStore(imgOutput, coords, vec4(velocityVIEW,1.0));
} 

