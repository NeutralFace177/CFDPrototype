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

struct DataGroup4f {
    float right;
    float left;
    float up;
    float down;
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

layout (std430, binding = 7) buffer out_fluxes {
    //y faces are vertical, as y is normal to the face
    Fields2D[] yFaceFlux;
};

//face is indexed to the forward cell
uint cellCoordToIndex(int i, int j) {
    return i*((gl_NumWorkGroups.y-1))+j;
}
uint faceCoordToIndex(int i, int j) {
    return i*(gl_NumWorkGroups.y)+j;
}
ivec2 workGroup = ivec2(gl_GlobalInvocationID.xy);
//ivec3 localGroup = ivec2(gl_LocalInvocationID.xy);

int i = workGroup.x;// * local_size_x + localGroup.x;
int j = workGroup.y;// * local_size_y + localGroup.y;
uint index = cellCoordToIndex(i, j);
uint faceIndex = faceCoordToIndex(i,j);
//iDataGroup4 indices = iDataGroup4(coordToIndex(i+1,j),coordToIndex(i-1,j),coordToIndex(i,j+1),coordToIndex(i,j-1));

float BC(int valId, int I, int J, int iOffset, int jOffset) {
    uint newIndex = cellCoordToIndex(int(clamp(I+iOffset,0,int(gl_NumWorkGroups.x-1))),int(clamp(J+jOffset,0,int(gl_NumWorkGroups.y-2))));
    bool objectFlag = false;
    if (mesh[newIndex] == 1) {
        newIndex = cellCoordToIndex(I,J);
        objectFlag = true;
    }
    int dir;
    if (iOffset != 0 && jOffset != 0) {
        dir = 2;
    } else if (iOffset != 0) {
        dir = 0;
    } else {
        dir = 1;
    }
    if (objectFlag) {
        switch (valId) {
            case 0:
                return fields[newIndex].d;
            case 1:
                return (dir == 2 || dir == 0) ? 0 : fields[newIndex].u;
            case 2:
                return (dir == 2 || dir == 1) ? 0 : fields[newIndex].v;
            case 3:
                return fields[newIndex].E - 0.5 * (fields[newIndex].u * fields[newIndex].u + fields[newIndex].v * fields[newIndex].v) + 0.5 * (pow((dir == 2 || dir == 0) ? 0 : fields[newIndex].u,2) + pow((dir == 2 || dir == 1) ? 0 : fields[newIndex].v,2));
            case 4:
                return fields[newIndex].S;
        }
    } else if (I+iOffset < 0) { 
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
    } else if (I+iOffset >= gl_NumWorkGroups.x) {
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
    } else if (J+jOffset < 0) {
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
    } else if (J+jOffset >= gl_NumWorkGroups.y-1) {
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

float BC(int valId, int iOffset, int jOffset) {
    return BC(valId, i, j, iOffset, jOffset);
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
   // return BC(0,iOffset,jOffset) * 0.286 * ((BC(3,iOffset,jOffset)-0.5*(BC(1,iOffset,jOffset)*BC(1,iOffset,jOffset)+BC(2,iOffset,jOffset)*BC(2,iOffset,jOffset)))/0.718);
   return (1.4-1.0)*BC(0,iOffset,jOffset) * (BC(3,iOffset,jOffset)-0.5*(BC(1,iOffset,jOffset)*BC(1,iOffset,jOffset)+BC(2,iOffset,jOffset)*BC(2,iOffset,jOffset)));
}

//TODO: offset indices cannot be passed as original indices (fix ts)
float CD(int valId, int dim, bool forwards) {
    int I = forwards ? i-1 : i;
    int J = forwards ? j-1 : j;
    if (dim == 0) {
        return (BC(valId,I,J,0,0)+BC(valId,I,J,forwards?1:-1,0))/2.0;
    } else {
        return (BC(valId,I,J,0,0)+BC(valId,I,J,0,forwards?1:-1))/2.0;
    }
}

float QUICK(int valId, int dim, bool forwards) {
    int I = forwards ? i-1 : i;
    int J = forwards ? j-1 : j;
    if (dim == 0) {
        return (BC(1,I,J,0,0) >= 0) ? -0.125*BC(valId,I,J,forwards?-1:-2,0)+0.75*BC(valId,I,J,forwards?0:-1,0)+0.375*BC(valId,I,J,forwards?1:0,0) : 0.375*BC(valId,I,J,forwards?0:-1,0)+0.75*BC(valId,I,J,forwards?1:0,0)-0.125*BC(valId,I,J,forwards?2:1,0);
    } else {
        return (BC(2,I,J,0,0) >= 0) ? -0.125*BC(valId,I,J,0,forwards?-1:-2)+0.75*BC(valId,I,J,0,forwards?0:-1)+0.375*BC(valId,I,J,0,forwards?1:0) : 0.375*BC(valId,I,J,0,forwards?0:-1)+0.75*BC(valId,I,J,0,forwards?1:0)-0.125*BC(valId,I,J,0,forwards?2:1);
    }
}

float FOU(int valId, int dim, bool forwards) {
    int I = forwards ? i-1 : i;
    int J = forwards ? j-1 : j;
    if (dim == 0) {
        return BC(1,I,J,0,0) >= 0 ? (forwards ? BC(valId,I,J,0,0) : BC(valId,I,J,-1,0)) : (forwards ? BC(valId,I,J,1,0) : BC(valId,I,J,0,0));
    } else {
        return BC(2,I,J,0,0) >= 0 ? (forwards ? BC(valId,I,J,0,0) : BC(valId,I,J,0,-1)) : (forwards ? BC(valId,I,J,0,1) : BC(valId,I,J,0,0));
    }
}

float SOU(int valId, int dim, bool forwards) {
    int I = forwards ? i-1 : i;
    int J = forwards ? j-1 : j;
    if (dim == 0)
    {
        return forwards ? ((BC(1,I,J,0,0) >= 0) ? BC(valId,I,J,0,0) + (BC(valId,I,J,0,0) - BC(valId,I,J,-1,0)) / 2.0 : BC(valId,I,J,1,0) - (BC(valId,I,J,1,0) - BC(valId,I,J,0,0)) / 2.0)
            : (BC(1,I,J,0,0) < 0 ? BC(valId,I,J,-1,0) + (BC(valId,I,J,-1,0)-BC(valId,I,J,-2,0)) /2.0 : BC(valId,I,J,0,0) - (BC(valId,I,J,0,0) - BC(valId,I,J,-1,0)) / 2.0);
    } else
    {
        return forwards ? ((BC(2,I,J,0,0) >= 0) ? BC(valId,I,J,0,0) + (BC(valId,I,J,0,0) - BC(valId,I,J,0,-1)) / 2.0 : BC(valId,I,J,0,1) - (BC(valId,I,J,0,1) - BC(valId,I,J,0,0)) / 2.0)
            : (BC(2,I,J,0,0) < 0 ? BC(valId,I,J,0,-1) + (BC(valId,I,J,0,-1)-BC(valId,I,J,0,-2)) /2.0 : BC(valId,I,J,0,0) - (BC(valId,I,J,0,0) - BC(valId,I,J,0,-1)) / 2.0);
    }
}	

//zeroth order buns ahh
float ZOS(int valId, int dim, bool forwards) {
    int I = forwards ? i-1 : i;
    int J = forwards ? j-1 : j;
    if (dim == 0) {
        return forwards ? (2.0*BC(valId,I,J,1,0)+BC(valId,I,J,-1,0)+BC(valId,I,J,0,0))/4.0 : (BC(valId,I,J,1,0)+2.0*BC(valId,I,J,-1,0)+BC(valId,I,J,0,0))/4.0;
    } else {
        return forwards ? (2.0*BC(valId,I,J,0,1)+BC(valId,I,J,0,-1)+BC(valId,I,J,0,0))/4.0 : (BC(valId,I,J,0,1)+2.0*BC(valId,I,J,0,-1)+BC(valId,I,J,0,0))/4.0;
    }
}

float vanLeer(float r) {
    return (r+abs(r))/(1.0+abs(r));
}

//with vanLeer
float SOULIM(int valId, int dim, bool forwards) {
    int I = forwards ? i-1 : i;
    int J = forwards ? j-1 : j;
    float r;
    if (dim==0) {
        r = (BC(valId,I,J,0,0)-BC(valId,I,J,-1,0))/(BC(valId,I,J,1,0)-BC(valId,I,J,0,0)+0.00001);
    } else {
        r = (BC(valId,I,J,0,0)-BC(valId,I,J,0,-1))/(BC(valId,I,J,0,1)-BC(valId,I,J,0,0)+0.00001);
    }

    if (dim == 0)
    {
        return forwards ? ((BC(1,I,J,0,0) >= 0) ? BC(valId,I,J,0,0) + 0.5 * vanLeer(r) * (BC(valId,I,J,0,0) - BC(valId,I,J,-1,0)) / 2.0 : BC(valId,I,J,1,0) - 0.5 * vanLeer(r) * (BC(valId,I,J,1,0) - BC(valId,I,J,0,0)) / 2.0)
            : (BC(1,I,J,0,0) >= 0 ? BC(valId,I,J,-1,0) + 0.5 * vanLeer(r) * (BC(valId,I,J,-1,0)-BC(valId,I,J,-2,0)) /2.0 : BC(valId,I,J,0,0) - 0.5 * vanLeer(r) * (BC(valId,I,J,0,0) - BC(valId,I,J,-1,0)) / 2.0);
    } else
    {
        return forwards ? ((BC(2,I,J,0,0) >= 0) ? BC(valId,I,J,0,0) + 0.5 * vanLeer(r) * (BC(valId,I,J,0,0) - BC(valId,I,J,0,-1)) / 2.0 : BC(valId,I,J,0,1) - 0.5 * vanLeer(r) * (BC(valId,I,J,0,1) - BC(valId,I,J,0,0)) / 2.0)
            : (BC(2,I,J,0,0) >= 0 ? BC(valId,I,J,0,-1) + 0.5 * vanLeer(r) * (BC(valId,I,J,0,-1)-BC(valId,I,J,0,-2)) /2.0 : BC(valId,I,J,0,0) - 0.5 * vanLeer(r) * (BC(valId,I,J,0,0) - BC(valId,I,J,0,-1)) / 2.0);
    }
}

float QUICKLIM(int valId, int dim, bool forwards) {
    int I = forwards ? i-1 : i;
    int J = forwards ? j-1 : j;
    float FL = FOU(valId, dim, forwards);
    float FH = QUICK(valId, dim, forwards);
    float r;
        if (dim==0) {
        r = (BC(valId,I,J,0,0)-BC(valId,I,J,-1,0))/(BC(valId,I,J,1,0)-BC(valId,I,J,0,0)+0.000001);
    } else {
        r = (BC(valId,I,J,0,0)-BC(valId,I,J,0,-1))/(BC(valId,I,J,0,1)-BC(valId,I,J,0,0)+0.000001);
    }
    return FL+0.5*vanLeer(r)*(FH-FL);
}

///// PLLLEEEAASSE SPEED I NEEEED TS 🙏
float WENO(int valId, int dim, bool forwards) {
    int I = forwards ? i-1 : i;
    int J = forwards ? j-1 : j;
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
        W1 = (1.0/3.0) * BC(valId,I,J,forwards?-2:-3,0) - (7.0/6.0) * BC(valId,I,J,forwards?-1:-2,0) + (11.0/6.0) * BC(valId,I,J,forwards?0:-1,0);
        W2 = (-1.0/6.0)*BC(valId,I,J,forwards?-1:-2,0) + (5.0/6.0) * BC(valId,I,J,forwards?0:-1,0) + (1.0/3.0) * BC(valId,I,J,forwards?1:0,0);
        W3 = (1.0/3.0) * BC(valId,I,J,forwards?0:-1,0) + (5.0/6.0) * BC(valId,I,J,forwards?1:0,0) - (1.0/6.0) * BC(valId,I,J,forwards?2:1,0);

        float b11 = (BC(valId,I,J,forwards?-2:-3,0) - 2.0 * BC(valId,I,J,forwards?-1:-2,0) + BC(valId,I,J,forwards?0:-1,0));
        float b12 = (BC(valId,I,J,forwards?-2:-3,0) - 4.0 * BC(valId,I,J,forwards?-1:-2,0) + 3.0 * BC(valId,I,J,forwards?0:-1,0));
        b1 = (13.0/12.0) * b11*b11 + (1.0/4.0) * b12*b12;
        
        float b21 = (BC(valId,I,J,forwards?-1:-2,0) - 2.0 * BC(valId,I,J,forwards?0:-1,0) + BC(valId,I,J,forwards?1:0,0));
        float b22 = (BC(valId,I,J,forwards?-1:-2,0) - BC(valId,I,J,forwards?1:0,0));
        b2 = (13.0/12.0) * b21*b21 + (1.0/4.0) * b22*b22;

        float b31 = (BC(valId,I,J,forwards?0:-1,0) - 2.0 * BC(valId,I,J,forwards?1:0,0) + BC(valId,I,J,forwards?2:1,0));
        float b32 = (3.0 * BC(valId,I,J,forwards?0:-1,0) - 4.0 * BC(valId,I,J,forwards?1:0,0) + BC(valId,I,J,forwards?2:1,0));
        b3 = (13.0/12.0) * b31*b31 + (1.0/4.0) * b32*b32;
    } else {
        W1 = (1.0/3.0) * BC(valId,I,J,0,forwards?-2:-3) - (7.0/6.0) * BC(valId,I,J,0,forwards?-1:-2) + (11.0/6.0) * BC(valId,I,J,0,forwards?0:-1);
        W2 = (-1.0/6.0)*BC(valId,I,J,0,forwards?-1:-2) + (5.0/6.0) * BC(valId,I,J,0,forwards?0:-1) + (1.0/3.0) * BC(valId,I,J,0,forwards?1:0);
        W3 = (1.0/3.0) * BC(valId,I,J,0,forwards?0:-1) + (5.0/6.0) * BC(valId,I,J,0,forwards?1:0) - (1.0/6.0) * BC(valId,I,J,0,forwards?2:1);

        float b11 = (BC(valId,I,J,0,forwards?-2:-3) - 2.0 * BC(valId,I,J,0,forwards?-1:-2) + BC(valId,I,J,0,forwards?0:-1));
        float b12 = (BC(valId,I,J,0,forwards?-2:-3) - 4.0 * BC(valId,I,J,0,forwards?-1:-2) + 3.0 * BC(valId,I,J,0,forwards?0:-1));
        b1 = (13.0/12.0) * b11*b11 + (1.0/4.0) * b12*b12;
        
        float b21 = (BC(valId,I,J,0,forwards?-1:-2) - 2.0 * BC(valId,I,J,0,forwards?0:-1) + BC(valId,I,J,0,forwards?1:0));
        float b22 = (BC(valId,I,J,0,forwards?-1:-2) - BC(valId,I,J,0,forwards?1:0));
        b2 = (13.0/12.0) * b21*b21 + (1.0/4.0) * b22*b22;

        float b31 = (BC(valId,I,J,0,forwards?0:-1) - 2.0 * BC(valId,I,J,0,forwards?1:0) + BC(valId,I,J,0,forwards?2:1));
        float b32 = (3.0 * BC(valId,I,J,0,forwards?0:-1) - 4.0 * BC(valId,I,J,0,forwards?1:0) + BC(valId,I,J,0,forwards?2:1));
        b3 = (13.0/12.0) * b31*b31 + (1.0/4.0) * b32*b32;
    }
    a1 = (1.0/(10.0 * (b1+0.1)*(b1+0.000001)));
    a2 = (6.0/(10.0 * (b2+0.1)*(b2+0.000001)));
    a3 = (3.0/(10.0 * (b3+0.1)*(b3+0.000001)));
    float aSUM = a1+a2+a3;

    w1 = a1/aSUM;
    w2 = a2/aSUM;
    w3 = a3/aSUM;
    return w1*W1+w2*W2+w3*W3;
}

float SIGMA(int valId, int dim, bool forwards) {
    int I = forwards ? i-1 : i;
    int J = forwards ? j-1 : j;
    return (-1.0/6.0)*BC(valId,I,J,forwards?-1:-2,0) + (5.0/6.0) * BC(valId,I,J,forwards?0:-1,0) + (1.0/3.0) * BC(valId,I,J,forwards?1:0,0);;
}

float WENOLIM(int valId, int dim, bool forwards) {
    int I = forwards ? i-1 : i;
    int J = forwards ? j-1 : j;
    float FL = CD(valId, dim, forwards);
    float FH = WENO(valId, dim, forwards);
    float r;
        if (dim==0) {
        r = (BC(valId,I,J,0,0)-BC(valId,I,J,-1,0))/(BC(valId,I,J,1,0)-BC(valId,I,J,0,0)+0.000001);
    } else {
        r = (BC(valId,I,J,0,0)-BC(valId,I,J,0,-1))/(BC(valId,I,J,0,1)-BC(valId,I,J,0,0)+0.000001);
    }
    return FL+vanLeer(r)*(FH-FL);
}

float Scheme(int valId, int dim, bool forwards) {
    return WENO(valId,dim,forwards);
}

void main() {
    //vertical faces (perp to x)
    float rhieChowToggle = 1.0;
    float pc = calcPressure(0,0);
    float pr = calcPressure(0,1);
    float pl = calcPressure(0,-1);
    float pR = (pc + pr)/2.0;
    float pL = (pc + pl)/2.0;

    float dR = Scheme(0,1,false);
    float dL = Scheme(0,1,true);

    float RCYF = 0.5 * (dt/BC(0,0,0) + dt/BC(0,0,1))*((pr-pc)/dy);
    float RCYB = 0.5 * (dt/BC(0,0,0) + dt/BC(0,0,-1))*((pc-pl)/dy);

    float uR = Scheme(1,1,false) + rhieChowToggle;
    float uL = Scheme(1,1,true) + rhieChowToggle;

    float vR = Scheme(2,1,false) + rhieChowToggle;// * RCYF;
    float vL = Scheme(2,1,true) + rhieChowToggle;// * RCYB;

    float ER = Scheme(3,1,false);
    float EL = Scheme(3,1,true);

    float sR = Scheme(4,1,false);
    float sL = Scheme(4,1,true);

    //F_K
    float dFR = dR*vR;
    float dFL = dL*vL;

    float uFR = dR*uR*vR;
    float uFL = dL*uL*vL;

    float vFR = dR*vR*vR+pR;
    float vFL = dL*vL*vL+pL;

    float EFR = vR*(dR*ER+pR);
    float EFL = vL*(dL*EL+pL);

    float sFL = dR*vR*sR;
    float sFR = dL*vL*sL;

    //speed of sound, wave speed
    float cR = sqrt(1.4 * pR / dR);
    float cL = sqrt(1.4 * pL / dL);

/*
    float dLdR = sqrt(dL)+sqrt(dR);
    float N2 = 0.5 * sqrt(dL)*sqrt(dR) / pow(dLdR,2);
    float dhat = (sqrt(dL)*cL*cL+sqrt(dR)*cR*cR)/(dLdR) + N2*pow(vR-vL,2);
    float vhat = (sqrt(dL)*vL+sqrt(dR)*vR)/dLdR;
    float S_L = vhat - dhat;
    float S_R = vhat + dhat;
    */
    float S_L = min(vL-cL,vR-cR);
    float S_R = max(vL+cL,vR+cR);

    float S_M = (pR-pL+dL*vL*(S_L-vL)-dR*vR*(S_R-vR))/(dL*(S_L-vL)-dR*(S_R-vR));

    float dMR = dR * (S_R-vR)/(S_R-S_M);
    float dML = dL * (S_L-vL)/(S_L-S_M);
    
    if (0 <= S_L) {
        yFaceFlux[faceIndex].d = dFL;
        yFaceFlux[faceIndex].u = uFL;
        yFaceFlux[faceIndex].v = vFL;
        yFaceFlux[faceIndex].E = EFL;
        yFaceFlux[faceIndex].S = sFL;
    } else if (S_L < 0 && 0 <= S_M) {

        float uML = dML * uL;
        float vML = dML * S_M;
        float EML = dML * (EL + (S_M-vL)*(S_M+pL/(dL*(S_L-vL))));
        float sML = dML * sL;

        yFaceFlux[faceIndex].d = dFL + S_L*(dML-dL);
        yFaceFlux[faceIndex].u = uFL + S_L*(uML-dL*uL);
        yFaceFlux[faceIndex].v = vFL + S_L*(vML-dL*vL);
        yFaceFlux[faceIndex].E = EFL + S_L*(EML-dL*EL);
        yFaceFlux[faceIndex].S = sFL + S_L*(sML-dL*sL);

    } else if (S_M <= 0 && 0 < S_R) {

        float uMR = dMR * uR;
        float vMR = dMR * S_M;
        float EMR = dMR * (ER + (S_M-vR)*(S_M+pR/(dR*(S_R-vR))));
        float sMR = dMR * sR;

        yFaceFlux[faceIndex].d = dFR + S_R*(dMR-dR);
        yFaceFlux[faceIndex].u = uFR + S_R*(uMR-dR*uR);
        yFaceFlux[faceIndex].v = vFR + S_R*(vMR-dR*vR);
        yFaceFlux[faceIndex].E = EFR + S_R*(EMR-dR*ER);
        yFaceFlux[faceIndex].S = sFR + S_R*(sMR-dR*sR);
    } else if (0 >= S_R) {
        yFaceFlux[faceIndex].d = dFR;
        yFaceFlux[faceIndex].u = uFR;
        yFaceFlux[faceIndex].v = vFR;
        yFaceFlux[faceIndex].E = EFR;
        yFaceFlux[faceIndex].S = sFR;
    }

} 
