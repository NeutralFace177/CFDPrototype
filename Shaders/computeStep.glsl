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
 //   DebugThing[] debug;
//};

layout (std430, binding = 6) buffer prevData {
    Fields2D[] prevFields;
};

layout (std430, binding = 7) buffer FH {
    //y faces are vertical, as y is normal to the face
    Fields2D[] yFaceFlux;
};

layout (std430, binding = 8) buffer FV {
    //x faces are vertical, as x is normal to the face
    Fields2D[] xFaceFlux;
};

uint coordToIndex(int i, int j) {
    return i*gl_NumWorkGroups.y+j;
}

uint HFaceCoordToIndex(int i, int j) {
    return i*((gl_NumWorkGroups.y+1))+j;
}

uint VFaceCoordToIndex(int i, int j) {
    return i*(gl_NumWorkGroups.y)+j;
}

uint width = gl_NumWorkGroups.x;
uint height = gl_NumWorkGroups.y;
ivec2 coords = ivec2(gl_GlobalInvocationID.xy);
int i = coords.x;
int j = coords.y;
uint index = coordToIndex(coords.x, coords.y);
iDataGroup4 indices = iDataGroup4(coordToIndex(coords.x+1,coords.y),coordToIndex(coords.x-1,coords.y),coordToIndex(coords.x,coords.y+1),coordToIndex(coords.x,coords.y-1));

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
                return fields[newIndex].E - 0.5 * (fields[newIndex].u * fields[newIndex].u + fields[newIndex].v * fields[newIndex].v);
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
                return 50.0;
            //v
            case 2:
                return 0;  
            //e
            case 3:
                return fields[newIndex].E - 0.5 * (fields[newIndex].u*fields[newIndex].u + fields[newIndex].v*fields[newIndex].v) + 0.5 * 50.0*50.0;
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
    } else if (j+jOffset >= height) {
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

vec3 calcStressTensor(int iOffset, int jOffset) {
    float uDx = 0;
    float uDy = 0;
    float vDx = 0;
    float vDy = 0;
    uDx = (BC(1,iOffset,jOffset) < 0) ? (BC(1,iOffset+1,jOffset) - BC(1,iOffset,jOffset)) / dx : (BC(1,iOffset,jOffset) - BC(1,iOffset-1,jOffset)) / dx;
    uDy = (BC(2,iOffset,jOffset) < 0) ? (BC(1,iOffset,jOffset+1) - BC(1,iOffset,jOffset)) / dy : (BC(1,iOffset,jOffset) - BC(1,iOffset,jOffset-1)) / dy;
    vDx = (BC(1,iOffset,jOffset) < 0) ? (BC(2,iOffset+1,jOffset) - BC(2,iOffset,jOffset)) / dx : (BC(2,iOffset,jOffset) - BC(2,iOffset-1,jOffset)) / dx;
    vDy = (BC(2,iOffset,jOffset) < 0) ? (BC(2,iOffset,jOffset+1) - BC(2,iOffset,jOffset)) / dy : (BC(2,iOffset,jOffset) - BC(2,iOffset,jOffset-1)) / dy; 
    
    float divU = uDx + vDy;
    float visc = 0.0000186;
    float visc2 = (2.0/2.0) * visc;
    //Txx Txy Tyy
    return vec3(visc2 * divU+2.0*visc*uDx, visc*(uDy+vDx), visc2*divU + 2.0*visc*vDy);
}
//velocity derivatives
vec4 Dv(int iOffset, int jOffset) {
    float uDx = 0;
    float uDy = 0;
    float vDx = 0;
    float vDy = 0;
    uDx = (BC(1,iOffset,jOffset) < 0) ? (BC(1,iOffset+1,jOffset) - BC(1,iOffset,jOffset)) / dx : (BC(1,iOffset,jOffset) - BC(1,iOffset-1,jOffset)) / dx;
    uDy = (BC(2,iOffset,jOffset) < 0) ? (BC(1,iOffset,jOffset+1) - BC(1,iOffset,jOffset)) / dy : (BC(1,iOffset,jOffset) - BC(1,iOffset,jOffset-1)) / dy;
    vDx = (BC(1,iOffset,jOffset) < 0) ? (BC(2,iOffset+1,jOffset) - BC(2,iOffset,jOffset)) / dx : (BC(2,iOffset,jOffset) - BC(2,iOffset-1,jOffset)) / dx;
    vDy = (BC(2,iOffset,jOffset) < 0) ? (BC(2,iOffset,jOffset+1) - BC(2,iOffset,jOffset)) / dy : (BC(2,iOffset,jOffset) - BC(2,iOffset,jOffset-1)) / dy; 
    return vec4(uDx,uDy,vDx,vDy);
}

float calcPressure(int iOffset, int jOffset) {
    return BC(0,iOffset,jOffset) * 0.286 * ((BC(3,iOffset,jOffset)-0.5*(BC(1,iOffset,jOffset)*BC(1,iOffset,jOffset)+BC(2,iOffset,jOffset)*BC(2,iOffset,jOffset)))/0.718);
}

vec2 calcHeatFlux(int iOffset, int jOffset) {
    float TDx;
    float TDy;
    float tmp; //temp temp (like temperary temperature)
    tmp = (BC(3,iOffset,jOffset)-0.5*(BC(1,iOffset,jOffset)*BC(1,iOffset,jOffset)+BC(2,iOffset,jOffset)*BC(2,iOffset,jOffset)))/0.718;
    TDx = (BC(1,iOffset,jOffset) < 0) ? (((BC(3,iOffset+1,jOffset)-0.5*(BC(1,iOffset+1,jOffset)*BC(1,iOffset+1,jOffset)+BC(2,iOffset+1,jOffset)*BC(2,iOffset+1,jOffset)))/0.718)-tmp) / dx : (tmp - ((BC(3,iOffset-1,jOffset)-0.5*(BC(1,iOffset-1,jOffset)*BC(1,iOffset-1,jOffset)+BC(2,iOffset-1,jOffset)*BC(2,iOffset-1,jOffset)))/0.718)) / dx;
    TDy = (BC(2,iOffset,jOffset) < 0) ? (((BC(3,iOffset,jOffset+1)-0.5*(BC(1,iOffset,jOffset+1)*BC(1,iOffset,jOffset+1)+BC(2,iOffset,jOffset+1)*BC(2,iOffset,jOffset+1)))/0.718)-tmp) / dy : (tmp - ((BC(3,iOffset,jOffset-1)-0.5*(BC(1,iOffset,jOffset-1)*BC(1,iOffset,jOffset-1)+BC(2,iOffset,jOffset-1)*BC(2,iOffset,jOffset-1)))/0.718)) / dy;
    return vec2(-0.02662 * TDx, -0.02662 * TDy);
}

vec2 calcSGradient(int iOffset, int jOffset) {
    float SDx;
    float SDy;
    SDx = (BC(1,iOffset,jOffset) < 0) ? (BC(4,iOffset+1,jOffset) - BC(4,iOffset,jOffset)) / dx : (BC(4,iOffset,jOffset)-BC(4,iOffset-1,jOffset)) / dx;
    SDy = (BC(2,iOffset,jOffset) < 0) ? (BC(4,iOffset,jOffset+1) - BC(4,iOffset,jOffset)) / dy : (BC(4,iOffset,jOffset)-BC(4,iOffset,jOffset-1)) / dy;
    return vec2(SDx, SDy);
}

float CD(int valId, int dim, bool forwards) {
    if (dim == 0) {
        switch (valId) {
            case 0:
                return (fields[index].d+BC(0,forwards?1:-1,0))/2.0;
            case 1:
                return (fields[index].u+BC(1,forwards?1:-1,0))/2.0;
            case 2:
                return (fields[index].v+BC(2,forwards?1:-1,0))/2.0;
            case 3:
                return (fields[index].E+BC(3,forwards?1:-1,0))/2.0;
            case 4:
                return (fields[index].S+BC(4,forwards?1:-1,0))/2.0;
        }
    } else {
        switch (valId) {
            case 0:
                return (fields[index].d+BC(0,0,forwards?1:-1))/2.0;
            case 1:
                return (fields[index].u+BC(1,0,forwards?1:-1))/2.0;
            case 2:
                return (fields[index].v+BC(2,0,forwards?1:-1))/2.0;
            case 3:
                return (fields[index].E+BC(3,0,forwards?1:-1))/2.0;
            case 4:
                return (fields[index].S+BC(4,0,forwards?1:-1))/2.0;
        }
    }
}

float QUICK(int valId, int dim, bool forwards) {
    if (dim == 0) {
        switch (valId) {
            case 0:
                return (fields[index].u >= 0) ? -0.125*BC(0,forwards?-1:-2,0)+0.75*BC(0,forwards?0:-1,0)+0.375*BC(0,forwards?1:0,0) : 0.375*BC(0,forwards?0:-1,0)+0.75*BC(0,forwards?1:0,0)-0.125*BC(0,forwards?2:1,0);
            case 1:
                return (fields[index].u >= 0) ? -0.125*BC(1,forwards?-1:-2,0)+0.75*BC(1,forwards?0:-1,0)+0.375*BC(1,forwards?1:0,0) : 0.375*BC(1,forwards?0:-1,0)+0.75*BC(1,forwards?1:0,0)-0.125*BC(1,forwards?2:1,0);
            case 2:
                return (fields[index].u >= 0) ? -0.125*BC(2,forwards?-1:-2,0)+0.75*BC(2,forwards?0:-1,0)+0.375*BC(2,forwards?1:0,0) : 0.375*BC(2,forwards?0:-1,0)+0.75*BC(2,forwards?1:0,0)-0.125*BC(2,forwards?2:1,0);
            case 3:
                return (fields[index].u >= 0) ? -0.125*BC(3,forwards?-1:-2,0)+0.75*BC(3,forwards?0:-1,0)+0.375*BC(3,forwards?1:0,0) : 0.375*BC(3,forwards?0:-1,0)+0.75*BC(3,forwards?1:0,0)-0.125*BC(3,forwards?2:1,0);
            case 4:
                return (fields[index].u >= 0) ? -0.125*BC(4,forwards?-1:-2,0)+0.75*BC(4,forwards?0:-1,0)+0.375*BC(4,forwards?1:0,0) : 0.375*BC(4,forwards?0:-1,0)+0.75*BC(4,forwards?1:0,0)-0.125*BC(4,forwards?2:1,0);
        }
    } else {
        switch (valId) {
            case 0:
                return (fields[index].v >= 0) ? -0.125*BC(0,0,forwards?-1:-2)+0.75*BC(0,0,forwards?0:-1)+0.375*BC(0,0,forwards?1:0) : 0.375*BC(0,0,forwards?0:-1)+0.75*BC(0,0,forwards?1:0)-0.125*BC(0,0,forwards?2:1);
            case 1:
                return (fields[index].v >= 0) ? -0.125*BC(1,0,forwards?-1:-2)+0.75*BC(1,0,forwards?0:-1)+0.375*BC(1,0,forwards?1:0) : 0.375*BC(1,0,forwards?0:-1)+0.75*BC(1,0,forwards?1:0)-0.125*BC(1,0,forwards?2:1);
            case 2:
                return (fields[index].v >= 0) ? -0.125*BC(2,0,forwards?-1:-2)+0.75*BC(2,0,forwards?0:-1)+0.375*BC(2,0,forwards?1:0) : 0.375*BC(2,0,forwards?0:-1)+0.75*BC(2,0,forwards?1:0)-0.125*BC(2,0,forwards?2:1);
            case 3:
                return (fields[index].v >= 0) ? -0.125*BC(3,0,forwards?-1:-2)+0.75*BC(3,0,forwards?0:-1)+0.375*BC(3,0,forwards?1:0) : 0.375*BC(3,0,forwards?0:-1)+0.75*BC(3,0,forwards?1:0)-0.125*BC(3,0,forwards?2:1);
            case 4:
                return (fields[index].v >= 0) ? -0.125*BC(4,0,forwards?-1:-2)+0.75*BC(4,0,forwards?0:-1)+0.375*BC(4,0,forwards?1:0) : 0.375*BC(4,0,forwards?0:-1)+0.75*BC(4,0,forwards?1:0)-0.125*BC(4,0,forwards?2:1);
        }
    }
}

float FOU(int valId, int dim, bool forwards) {
    if (dim == 0) {
        return fields[index].u >= 0 ? (forwards ? BC(valId,0,0) : BC(valId,-1,0)) : (forwards ? BC(valId,1,0) : BC(valId,0,0));
    } else {
        return fields[index].v >= 0 ? (forwards ? BC(valId,0,0) : BC(valId,0,-1)) : (forwards ? BC(valId,0,1) : BC(valId,0,0));
    }
}

float SOU(int valId, int dim, bool forwards)
{
    if (dim == 0)
    {
        return forwards ? ((BC(1,0,0) >= 0) ? BC(valId,0,0) + (BC(valId,0,0) - BC(valId,-1,0)) / 2.0 : BC(valId,1,0) - (BC(valId,1,0) - BC(valId,0,0)) / 2.0)
            : (BC(1,0,0) < 0 ? BC(valId,-1,0) + (BC(valId,-1,0)-BC(valId,-2,0)) /2.0 : BC(valId,0,0) - (BC(valId,0,0) - BC(valId,-1,0)) / 2.0);
    } else
    {
        return forwards ? ((BC(2,0,0) >= 0) ? BC(valId,0,0) + (BC(valId,0,0) - BC(valId,0,-1)) / 2.0 : BC(valId,0,1) - (BC(valId,0,1) - BC(valId,0,0)) / 2.0)
            : (BC(2,0,0) < 0 ? BC(valId,0,-1) + (BC(valId,0,-1)-BC(valId,0,-2)) /2.0 : BC(valId,0,0) - (BC(valId,0,0) - BC(valId,0,-1)) / 2.0);
    }
}

//zeroth order buns ahh
float ZOS(int valId, int dim, bool forwards) {
    if (dim == 0) {
        return forwards ? (2.0*BC(valId,1,0)+BC(valId,-1,0)+BC(valId,0,0))/4.0 : (BC(valId,1,0)+2.0*BC(valId,-1,0)+BC(valId,0,0))/4.0;
    } else {
        return forwards ? (2.0*BC(valId,0,1)+BC(valId,0,-1)+BC(valId,0,0))/4.0 : (BC(valId,0,1)+2.0*BC(valId,0,-1)+BC(valId,0,0))/4.0;
    }
}

float vanLeer(float r) {
    return (r+abs(r))/(1.0+abs(r));
}

//with vanLeer
float SOULIM(int valId, int dim, bool forwards)
{
    float r;
    if (dim==0) {
        r = (BC(valId,0,0)-BC(valId,-1,0))/(BC(valId,1,0)-BC(valId,0,0)+0.0001);
    } else {
        r = (BC(valId,0,0)-BC(valId,0,-1))/(BC(valId,0,1)-BC(valId,0,0)+0.0001);
    }

    if (dim == 0)
    {
        return forwards ? ((BC(1,0,0) >= 0) ? BC(valId,0,0) + 0.5 * vanLeer(r) * (BC(valId,0,0) - BC(valId,-1,0)) / 2.0 : BC(valId,1,0) - 0.5 * vanLeer(r) * (BC(valId,1,0) - BC(valId,0,0)) / 2.0)
            : (BC(1,0,0) >= 0 ? BC(valId,-1,0) + 0.5 * vanLeer(r) * (BC(valId,-1,0)-BC(valId,-2,0)) /2.0 : BC(valId,0,0) - 0.5 * vanLeer(r) * (BC(valId,0,0) - BC(valId,-1,0)) / 2.0);
    } else
    {
        return forwards ? ((BC(2,0,0) >= 0) ? BC(valId,0,0) + 0.5 * vanLeer(r) * (BC(valId,0,0) - BC(valId,0,-1)) / 2.0 : BC(valId,0,1) - 0.5 * vanLeer(r) * (BC(valId,0,1) - BC(valId,0,0)) / 2.0)
            : (BC(2,0,0) >= 0 ? BC(valId,0,-1) + 0.5 * vanLeer(r) * (BC(valId,0,-1)-BC(valId,0,-2)) /2.0 : BC(valId,0,0) - 0.5 * vanLeer(r) * (BC(valId,0,0) - BC(valId,0,-1)) / 2.0);
    }
}

float QUICKLIM(int valId, int dim, bool forwards) {
    float FL = FOU(valId, dim, forwards);
    float FH = QUICK(valId, dim, forwards);
    float r;
        if (dim==0) {
        r = (BC(valId,0,0)-BC(valId,-1,0))/(BC(valId,1,0)-BC(valId,0,0)+0.1);
    } else {
        r = (BC(valId,0,0)-BC(valId,0,-1))/(BC(valId,0,1)-BC(valId,0,0)+0.1);
    }
    return FL+0.5*vanLeer(r)*(FH-FL);
}

///// PLLLEEEAASSE SPEED I NEEEED TS 🙏
float WENO(int valId, int dim, bool forwards) {
    float W1;
    float W2;
    float W3;
    float b1;
    float b2;
    float b3;
    float a1;
    float a2;
    float a3;
    float w1;
    float w2;
    float w3;
    if (dim == 0) {
        W1 = (1.0/3.0) * BC(valId,forwards?-2:-3,0) - (7.0/6.0) * BC(valId,forwards?-1:-2,0) + (11.0/6.0) * BC(valId,forwards?0:-1,0);
        W2 = (-1.0/6.0)*BC(valId,forwards?-1:-2,0) + (5.0/6.0) * BC(valId,forwards?0:-1,0) + (1.0/3.0) * BC(valId,forwards?1:0,0);
        W3 = (1.0/3.0) * BC(valId,forwards?0:-1,0) + (5.0/6.0) * BC(valId,forwards?1:0,0) - (1.0/6.0) * BC(valId,forwards?2:1,0);

        float b11 = (BC(valId,forwards?-2:-3,0) - 2.0 * BC(valId,forwards?-1:-2,0) + BC(valId,forwards?0:-1,0));
        float b12 = (BC(valId,forwards?-2:-3,0) - 4.0 * BC(valId,forwards?-1:-2,0) + 3.0 * BC(valId,forwards?0:-1,0));
        b1 = (13.0/12.0) * b11*b11 + (1.0/4.0) * b12*b12;
        
        float b21 = (BC(valId,forwards?-1:-2,0) - 2.0 * BC(valId,forwards?0:-1,0) + BC(valId,forwards?1:0,0));
        float b22 = (BC(valId,forwards?-1:-2,0) - BC(valId,forwards?1:0,0));
        b2 = (13.0/12.0) * b21*b21 + (1.0/4.0) * b22*b22;

        float b31 = (BC(valId,forwards?0:-1,0) - 2.0 * BC(valId,forwards?1:0,0) + BC(valId,forwards?2:1,0));
        float b32 = (3.0 * BC(valId,forwards?0:-1,0) - 4.0 * BC(valId,forwards?1:0,0) + BC(valId,forwards?2:1,0));
        b3 = (13.0/12.0) * b31*b31 + (1.0/4.0) * b32*b32;
    } else {
        W1 = (1.0/3.0) * BC(valId,0,forwards?-2:-3) - (7.0/6.0) * BC(valId,0,forwards?-1:-2) + (11.0/6.0) * BC(valId,0,forwards?0:-1);
        W2 = (-1.0/6.0)*BC(valId,0,forwards?-1:-2) + (5.0/6.0) * BC(valId,0,forwards?0:-1) + (1.0/3.0) * BC(valId,0,forwards?1:0);
        W3 = (1.0/3.0) * BC(valId,0,forwards?0:-1) + (5.0/6.0) * BC(valId,0,forwards?1:0) - (1.0/6.0) * BC(valId,0,forwards?2:1);

        float b11 = (BC(valId,0,forwards?-2:-3) - 2.0 * BC(valId,0,forwards?-1:-2) + BC(valId,0,forwards?0:-1));
        float b12 = (BC(valId,0,forwards?-2:-3) - 4.0 * BC(valId,0,forwards?-1:-2) + 3.0 * BC(valId,0,forwards?0:-1));
        b1 = (13.0/12.0) * b11*b11 + (1.0/4.0) * b12*b12;
        
        float b21 = (BC(valId,0,forwards?-1:-2) - 2.0 * BC(valId,0,forwards?0:-1) + BC(valId,0,forwards?1:0));
        float b22 = (BC(valId,0,forwards?-1:-2) - BC(valId,0,forwards?1:0));
        b2 = (13.0/12.0) * b21*b21 + (1.0/4.0) * b22*b22;

        float b31 = (BC(valId,0,forwards?0:-1) - 2.0 * BC(valId,0,forwards?1:0) + BC(valId,0,forwards?2:1));
        float b32 = (3.0 * BC(valId,0,forwards?0:-1) - 4.0 * BC(valId,0,forwards?1:0) + BC(valId,0,forwards?2:1));
        b3 = (13.0/12.0) * b31*b31 + (1.0/4.0) * b32*b32;
    }
    a1 = (1.0/(10.0 * (b1+0.1)*(b1+0.1)));
    a2 = (6.0/(10.0 * (b2+0.1)*(b2+0.1)));
    a3 = (3.0/(10.0 * (b3+0.1)*(b3+0.1)));
    float aSUM = a1+a2+a3;

    w1 = a1/aSUM;
    w2 = a2/aSUM;
    w3 = a3/aSUM;
    return w1*W1+w2*W2+w3*W3;
}

float SIGMA(int valId, int dim, bool forwards) {
    return (-1.0/6.0)*BC(valId,forwards?-1:-2,0) + (5.0/6.0) * BC(valId,forwards?0:-1,0) + (1.0/3.0) * BC(valId,forwards?1:0,0);;
}

float WENOLIM(int valId, int dim, bool forwards) {
    float FL = CD(valId, dim, forwards);
    float FH = WENO(valId, dim, forwards);
    float r;
        if (dim==0) {
        r = (BC(valId,0,0)-BC(valId,-1,0))/(BC(valId,1,0)-BC(valId,0,0)+0.1);
    } else {
        r = (BC(valId,0,0)-BC(valId,0,-1))/(BC(valId,0,1)-BC(valId,0,0)+0.1);
    }
    return FL+vanLeer(r)*(FH-FL);
}

float Scheme(int valId, int dim, bool forwards) {
    return WENO(valId,dim,forwards);
}

Fields2D faceFlux(int dim, int I, int J) {
    if (dim == 0) {
        return xFaceFlux[VFaceCoordToIndex(i+I,j+J)];
    } else {
        return yFaceFlux[HFaceCoordToIndex(i+I,j+J)];
    }
}

void main() {
    DataGroupVec3 tensor = DataGroupVec3(calcStressTensor(0,0),calcStressTensor(1,0),calcStressTensor(-1,0),calcStressTensor(0,1),calcStressTensor(0,-1));
    DataGroupVec2 q = DataGroupVec2(calcHeatFlux(0,0),calcHeatFlux(1,0),calcHeatFlux(-1,0),calcHeatFlux(0,1),calcHeatFlux(0,-1));
    DataGroup p = DataGroup(calcPressure(0,0),calcPressure(1,0),calcPressure(-1,0),calcPressure(0,1),calcPressure(0,-1));
    DataGroupVec2 SGrad = DataGroupVec2(calcSGradient(0,0),calcSGradient(1,0),calcSGradient(-1,0),calcSGradient(0,1),calcSGradient(0,-1));


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


    //Rhie Chow
    float RCXF = 0.5 * (dt/fields[index].d + dt/BC(0,1,0))*((p.right-p.center)/dx);
    float RCXB = 0.5 * (dt/fields[index].d + dt/BC(0,-1,0))*((p.center-p.left)/dx);
    float RCYF = 0.5 * (dt/fields[index].d + dt/BC(0,0,1))*((p.up-p.center)/dx);
    float RCYB = 0.5 * (dt/fields[index].d + dt/BC(0,0,-1))*((p.center-p.down)/dx);

    float rhieChowToggle = 0.0;

//    pXFC += -RCXF;
//    pXBC += -RCXB;
  //  pYFC += -RCYF;
    //pYBC += -RCYB;

    float uXFC = CD(1,0,true);
    float uXBC = CD(1,0,false);
    float uYFC = CD(1,1,true);
    float uYBC = CD(1,1,false);


    float vXFC = CD(2,0,true);
    float vXBC = CD(2,0,false);
    float vYFC = CD(2,1,true);
    float vYBC = CD(2,1,false);


    float SDxXF = (SGrad.center.x + SGrad.right.x)/2.0;
    float SDxXB = (SGrad.center.x + SGrad.left.x)/2.0;
    float SDyYF = (SGrad.center.y + SGrad.up.y)/2.0;
    float SDyYB = (SGrad.center.y + SGrad.down.y)/2.0;

    float pressureToggle = 1.0;

    Fields2D XF = faceFlux(0,1,0);
    Fields2D XB = faceFlux(0,0,0);
    Fields2D YF = faceFlux(1,0,1);
    Fields2D YB = faceFlux(1,0,0);


    if (mesh[index] == 1) {
        outFields[index].d = 0;
        outFields[index].u = 0;
        outFields[index].v = 0;
        outFields[index].E = 0;
        outFields[index].S = 0;
    } else if (true) {
        outFields[index].d = fields[index].d + dt * (-(XF.d - XB.d) / dx - (YF.d - YB.d) / dy);
        outFields[index].u = fields[index].u + dt * (1.0 / fields[index].d) * (-(XF.u - XB.u) / dx -
                            (YF.u - YB.u) / dy);// + (TxxXF - TxxXB) / dx + (TxyYF - TxyYB) / dy);
        outFields[index].v = fields[index].v + dt * (1.0 / fields[index].d) * (-(XF.v - XB.v) / dx
                            - (YF.v - YB.v) / dy 
                            );//+ (TxyXF - TxyXB) / dx + (TyyYF - TyyYB) / dy);
        outFields[index].E = fields[index].E + dt * (1.0 / fields[index].d) * (-(XF.E - XB.E) / dx
                        - (YF.E - YB.E) / dy);
                        //+((uXFC * TxxXF + vXFC * TxyXF - qxXF) - (uXBC * TxxXB + vXBC * TxyXB - qxXB)) / dx
                        //+ ((uYFC * TxyYF + vYFC * TyyYF - qyYF) - (uYBC * TxyYB + vYBC * TyyYB - qyYB)) / dy);
        outFields[index].S = fields[index].S + dt * (1.0 / fields[index].d) * (-(XF.S - XB.S) / dx - (YF.S - YB.S) / dy + 0.05*(SDxXF - SDxXB) / dx + 0.05*(SDyYF - SDyYB) / dy);
    } else {
//        outFields[index].d = (4.0*fields[index].d-prevFields[index].d + dt * (-(dXF * uXF - dXB * uXB) / dx - (dYF * vYF - dYB * vYB) / dy))/3.0;
//        outFields[index].u = (4.0*fields[index].u-prevFields[index].u + (1.0 / fields[index].d) * dt * (-((dXF * uXF * uXF + pressureToggle * pXFC) - (dXB * uXB * uXB + pressureToggle * pXBC)) / dx -
 //                           (dYF * uYF * vYF - dYB * uYB * vYB) / dy + (TxxXF - TxxXB) / dx + (TxyYF - TxyYB) / dy))/3.0;
   //     outFields[index].v = (4.0*fields[index].v-prevFields[index].v + (1.0 / fields[index].d) * dt * (-(dXF * uXF * vXF - dXB * uXB * vXB) / dx
     //                       - ((dYF * vYF * vYF + pressureToggle * pYFC) - (dYB * vYB * vYB + pressureToggle * pYBC)) / dy 
       //                     + (TxyXF - TxyXB) / dx + (TyyYF - TyyYB) / dy))/3.0;
//        outFields[index].E = (4.0*fields[index].E-prevFields[index].E + (1.0 / fields[index].d) * dt * (-(uXF * (dXF * EXF + pressureToggle * pXFC) - uXB * (dXB * EXB + pressureToggle * pXBC)) / dx
  //                      - (vYF * (dYF * EYF + pressureToggle * pYFC) - vYB * (dYB * EYB + pressureToggle * pYBC)) / dy
    //                    +((uXFC * TxxXF + vXFC * TxyXF - qxXF) - (uXBC * TxxXB + vXBC * TxyXB - qxXB)) / dx
      //                  + ((uYFC * TxyYF + vYFC * TyyYF - qyYF) - (uYBC * TxyYB + vYBC * TyyYB - qyYB)) / dy))/3.0;
     //   outFields[index].S = fields[index].S + (1.0 / fields[index].d) * dt * (-(dXF * uXF * SXF - dXB * uXB * SXB) / dx - (dYF * vYF * SYF - dYB * vYB * SYB) / dy + 0.05*(SDxXF - SDxXB) / dx + 0.05*(SDyYF - SDyYB) / dy);
    }

    vec3 SVIEW = hsv2rgb(vec3(outFields[index].S*0.75,1.0,1.0));
    vec3 sEdVIEW = vec3(sqrt(outFields[index].u*outFields[index].u+outFields[index].v*outFields[index].v)/60.0,outFields[index].E / 30000.0,outFields[index].d/2.5);
    vec3 velocityVIEW = vec3(abs(outFields[index].u/60.0),0,abs(outFields[index].v)/12.0);
    vec3 uVIEW = vec3(outFields[index].u/120.0,0,-outFields[index].u/4.0);
    vec3 vVIEW = vec3(outFields[index].v/25.0,0,-outFields[index].v/25.0);

   // debug[index].f2d = mesh[index];

    ///TODO: IMPROVE VORTICITY CALCULATIONS TS LOWK LAZY AND UNOPTIMIZED
    vec4 DV = Dv(coords.x,coords.y);
    vec3 vorticityVIEW = vec3(DV.z-DV.y,0,-(DV.z-DV.y));
    imageStore(imgOutput, coords, vec4(sEdVIEW,1.0));
    if (mesh[index] == 1) {
        imageStore(imgOutput, coords, vec4(velocityVIEW,1.0));
    }
} 

