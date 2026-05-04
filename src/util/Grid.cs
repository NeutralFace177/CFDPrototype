using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Numerics;

namespace CFDPrototype.util
{
    struct Field2D
    {
        public float d = 0;
        public float u = 0;
        public float v = 0;
        public float E = 0;
        public float S = 0;

        public Field2D(float d, float u, float v, float E, float S)
        {
            this.d = d;
            this.u = u; 
            this.v = v; 
            this.E = E; 
            this.S = S;
        }
    }

    enum VT
    {
        d,
        u,
        v,
        w,
        E,
        T,
        S
    }

    enum Dim
    {
        x,y,z
    }

    struct Cell2D
    {
        //vertices (probably faster????), though indices (memory efficient) idk which is better
        int[]? vertexIndices;
        float x, y;
        Vector2[]? vertices;

        public Cell2D(int[] indices)
        {
            vertexIndices = indices;
            x = 0;
            y = 0;
            vertices = null;
        }
        public Cell2D(Vector2[] vertices)
        {
            this.vertices = vertices;
            x = 0;
            y = 0;
            vertexIndices = null;
        }

        public Cell2D(float a, float b)
        {
            x = a;
            y = b;
            vertices = null;
            vertexIndices = null;
        }

    }

    struct Cell3D
    {
        int[] vertexIndices;
        float u, v, w, p, d, e;
        public Cell3D(int[] indices, float u, float v,float w, float p, float d, float e)
        {
            vertexIndices = indices;
            this.u = u;
            this.v = v;
            this.w = w;
            this.p = p;
            this.d = d;
            this.e = e;
        }

    }

    class Grid
    {
        Vector2[] vertices;
        public Cell2D[,] cells;
        public float[,] u, v, p, d, e, S;
        int width;
        int height;
        public float[,] TxxA;
        public float[,] TxyA;
        public float[,] TyyA;
        float[,] qx,qy;
        float[,] T, SDx, SDy;
        bool[,] pC, qC, TC, tensorC, SDC;
        float dx = 0.25f;
        float dy = 0.25f;
        int unsetValue = 0b0_11111111_10101010101010101010101;
        int noValIDSet = 0b0_11111111_11111000000000000011111;
        int pressureToggle = 1;
        //System.Runtime.CompilerServices.Unsafe.As<int, float>(ref unsetValue)
        public Grid(int width, int height)
        {
            this.width = width;
            this.height = height;
            //instantiate init type shih
            vertices = new Vector2[(width+1) * (height+1)];
            cells = new Cell2D[width,height];
            u = new float[width,height];
            v = new float[width, height];
            d = new float[width, height];
            e = new float[width, height];
            S = new float[width, height];
            p = new float[width + 2, height + 2];
            pC = new bool[width + 2, height + 2];
            TxxA = new float[width + 2, height + 2];
            TxyA = new float[width + 2, height + 2];
            TyyA = new float[width + 2, height + 2];
            tensorC = new bool[width + 2, height + 2];
            qx = new float[width + 2, height + 2];
            qy = new float[width + 2, height + 2];
            qC = new bool[width + 2, height + 2];
            T = new float[width + 2, height + 2];
            TC = new bool[width + 2, height + 2];
            SDx = new float[width + 2, height + 2];
            SDy = new float[width + 2, height + 2];
            SDC = new bool[width + 2, height + 2];
            for (int i = 0; i < width; i++)
            {
                for (int j = 0; j < height; j++)
                {
                    float b = 0;
                    TxxA[i,j] = b;
                    TxyA[i,j] = b;
                    TyyA[i,j] = b;
                    if (j == height - 1)
                    {
                        TxxA[i,j+1] = b;
                        TxyA[i,j+1] = b;
                        TyyA[i,j+1] = b;
                        TxxA[i,j + 2] = b;
                        TxyA[i,j + 2] = b;
                        TyyA[i,j + 2] = b;
                        if (i == width - 1)
                        {
                            TxxA[i + 1,j + 1] = b;
                            TxyA[i + 1,j + 1] = b;
                            TyyA[i + 1,j + 1] = b;
                            TxxA[i + 2,j + 1] = b;
                            TxyA[i + 2,j + 1] = b;
                            TyyA[i + 2,j + 1] = b;

                            TxxA[i + 1,j + 2] = b;
                            TxyA[i + 1,j + 2] = b;
                            TyyA[i + 1,j + 2] = b;
                            TxxA[i + 2,j + 2] = b;
                            TxyA[i + 2,j + 2] = b;
                            TyyA[i + 2,j + 2] = b;
                        }
                    }

                    cells[i,j] = new Cell2D(i, j);
                   // u[i, j] = (float)((1f - Math.Pow(Math.Cos(Math.PI * i / width), 4)) * (1f - Math.Pow(Math.Cos(Math.PI * j / height), 4)) * Math.Sin(Math.PI * j / (0.5f*height)));
                   // v[i, j] = 0;
                    //u[i, j] = (float)(Math.Pow(Math.Sin(Math.PI * i / width),25)* Math.Pow(Math.Sin(Math.PI * j / height), 25)) * 2f;
                    //v[i, j] = (float)(Math.Pow(Math.Sin(Math.PI * i / width), 25) * Math.Pow(Math.Sin(Math.PI * j / height), 25)) * 2f;
                    u[i, j] = Math.Pow((i+0.15*width) - 0.5f * width, 2) + Math.Pow(3*(j - 0.5f * height), 2) < Math.Pow((1.0 / 6.0f) * width, 2) ? 0.0f : 50;
                    v[i, j] = 0;
                    d[i,j] = 1.293f;
                    e[i, j] = 0.718f * 100f + 0.5f*((float)Math.Pow(u[i,j], 2) + (float)Math.Pow(v[i,j], 2));
                    S[i, j] = (float)i / (float)width;
                }
            }
        }

        public void StoreGrid(Field2D[,] field, int[,] mesh)
        {
            for (int i = 0; i < width; i++)
            {
                for (int j = 0; j < height; j++)
                {
                    field[i,j].d = d[i, j];
                    field[i,j].u = u[i, j];
                    field[i,j].v = v[i, j];
                    field[i,j].E = e[i, j];
                    field[i,j].S = S[i, j];
                    if (Math.Pow((i + 0.15 * width) - 0.5f * width, 2) + Math.Pow(3 * (j - 0.5f * height), 2) < Math.Pow((1.0f /  6.0f) * width, 2)) {
                        mesh[i, j] = 1;
                    }
                }
            }
        }

        //1st order central diff
        float CD(float[,] field, int i, int j, VT valId, Dim dim, bool forwards)
        {
            float val = 0;
            val = (field[i, j] + BC(field, i, j, valId, dim, forwards ? (sbyte)1 : (sbyte)-1)) / 2f;

            return val;
        }

        //1st order upwind --currently causes instabilities
        float FOU(float[,] field, int i, int j, VT valId, Dim dim, bool forwards)
        {
            float val;
            if (forwards)
            {
                val = (dim == Dim.x) ? (u[i, j] >= 0 ? field[i,j] : BC(field,i,j,valId,dim,1)) : (v[i, j] >= 0 ? field[i, j] : BC(field, i, j, valId, dim, 1));
            } else
            {
                val = (dim == Dim.x) ? (u[i, j] >= 0 ? BC(field, i, j, valId, dim, -1) : field[i,j]) : (v[i, j] >= 0 ? BC(field, i, j, valId, dim, -1) : field[i,j]);
            }
            return val;
        }

        //second order upwind --add flux limiters
        float SOU(float[,] field, int i, int j, VT valId, Dim dim, bool forwards)
        {
            float val = 0;
            if (dim == Dim.x)
            {
                val = forwards ? ((u[i, j] > 0) ? field[i, j] + (field[i, j] - BC(field, i, j, valId, dim, -1)) / 2f : BC(field, i, j, valId, dim, 1) - (BC(field, i, j, valId, dim, 1) - field[i, j]) / 2f)
                    : ((u[i, j] > 0) ? BC(field,i,j,valId,dim,-1) + (BC(field,i,j,valId,dim,-1)-BC(field, i, j, valId, dim, -2)) /2f : field[i, j] - (field[i, j] - BC(field, i, j, valId, dim, -1)) / 2f);
                    ;
            } else
            {
                val = forwards ? ((v[i, j] > 0) ? field[i, j] + (field[i, j] - BC(field, i, j, valId, dim, -1)) / 2f : BC(field, i, j, valId, dim, 1) - (BC(field, i, j, valId, dim, 1) - field[i, j]) / 2f)
    : ((v[i, j] > 0) ? BC(field, i, j, valId, dim, -1) + (BC(field, i, j, valId, dim, -1) - BC(field, i, j, valId, dim, -2)) / 2f : field[i, j] - (field[i, j] - BC(field, i, j, valId, dim, -1)) / 2f);
                ;
            }
            return val;
        }

        //currently in 2d so dim could be a bool but that just seems kinda wierd --deprecated
        float Scheme(float[,] value, int i, int j, VT valId, Dim dim, bool forwards)
        {
            float val = 0;
            switch (dim)
            {
                //x
                case Dim.x:
                    //boundary cond
                    if (i + (forwards ? 1:-1) < 0 || i + (forwards ? 1 : -1) >= width)
                    {
                        switch (valId)
                        {
                            //d
                            case VT.d:
                                val = value[i,j]; // + neumann * dx / 2
                                break;
                            //u
                            case VT.u:
                                val = (value[i,j]) / 2f;
                                break;
                            //v
                            case VT.v:
                                val = (value[i,j]) / 2f;
                                break;
                            //e
                            case VT.E:
                                val = value[i,j]; // + neumann * dx / 2
                                break;
                        }
                    } else
                    {
                        val = (value[i,j] + value[i + (forwards ? 1 : -1),j]) / 2f;
                    }
                    break;
                //y
                case Dim.y:
                    //boundary cond
                    if (j + (forwards ? 1 : -1) < 0 || j + (forwards ? 1 : -1) >= height)
                    {
                        switch (valId)
                        {
                            //d
                            case VT.d:
                                val = value[i,j]; // + neumann * dx / 2
                                break;
                            //u
                            case VT.u:
                                val = (value[i,j]) / 2f;
                                break;
                            //v
                            case VT.v:
                                val = (value[i,j]) / 2f;
                                break;
                            //e
                            case VT.E:
                                val = value[i,j]; // + neumann * dx / 2
                                break;
                        }
                    }
                    else
                    {
                        val = (value[i,j] + value[i,j + (forwards ? 1 : -1)]) / 2f;
                    }
                    break;
            }
                
            return val;
        }

        float BC(float[,] field, int i, int j, VT valId, Dim dim, sbyte dir)
        {
            if (i < 0 || i >= width || j < 0 || j >= height)
            {
                switch (valId)
                {
                    //𝜌
                    case VT.d:
                        return d[Math.Clamp(i, 0, width - 1), Math.Clamp(j, 0, height - 1)];
                    //u
                    case VT.u:
                        return 0;
                    //v
                    case VT.v:
                        return 0;
                    //E
                    case VT.E:
                        return e[Math.Clamp(i, 0, width - 1), Math.Clamp(j, 0, height - 1)];
                    case VT.T:
                        return e[Math.Clamp(i, 0, width - 1), Math.Clamp(j, 0, height - 1)]/0.718f;
                    case VT.S:
                        return S[Math.Clamp(i, 0, width - 1), Math.Clamp(j, 0, height - 1)];
                    default:
                        return System.Runtime.CompilerServices.Unsafe.As<int, float>(ref noValIDSet);

                }
            }
            switch (dim)
            {
                case Dim.x:
                    if (i+dir < 0 || i+dir >= width)
                    {
                        switch (valId)
                        {
                            //𝜌
                            case VT.d:
                                return d[i,j];
                            //u
                            case VT.u:
                                return 0;
                            //v
                            case VT.v:
                                return 0;
                            //E
                            case VT.E:
                                return e[i,j];
                            case VT.T:
                                return e[i,j]/0.718f;
                            case VT.S:
                                return S[i,j];
                            default:
                                return System.Runtime.CompilerServices.Unsafe.As<int, float>(ref noValIDSet);

                        }
                    } else
                    {
                        return field[i+dir,j];
                    }
                case Dim.y:
                    if (j + dir < 0 || j + dir >= height)
                    {
                        switch (valId)
                        {
                            //𝜌
                            case VT.d:
                                return d[i,j];
                            //u
                            case VT.u:
                                return 0;
                            //v
                            case VT.v:
                                return 0;
                            //E
                            case VT.E:
                                return e[i,j];
                            case VT.T:
                                return e[i,j]/0.718f;
                            case VT.S:
                                return S[i,j];
                            default:
                                return System.Runtime.CompilerServices.Unsafe.As<int, float>(ref noValIDSet);
                        }
                    }
                    else
                    {
                        return field[i,j+dir];
                    }
            }
            return 0;
        }

        public void calcStressTensor(int i, int j)
        {
            int ti = i + 1;
            int tj = j + 1;
            if (tensorC[ti, tj])
            {
                return;
            }
            float uDx = 0;
            float uDy = 0;
            float vDx = 0;
            float vDy = 0;
            float divU = 0;
            if ((i < 0 || i >= width || j < 0 || j >= height))
            {
                uDx = (u[Math.Clamp(i, 0, width - 1), Math.Clamp(j, 0, height - 1)] < 0) ? (BC(u, i, j, VT.u, Dim.x, 1) - BC(u, i, j, VT.u, Dim.x, 0)) / dx : (BC(u, i, j, VT.u, Dim.x, 0) - BC(u, i, j, VT.u, Dim.x, -1)) / dx;
                uDy = (v[Math.Clamp(i, 0, width - 1), Math.Clamp(j, 0, height - 1)] < 0) ? (BC(u, i, j, VT.u, Dim.y, 1) - BC(u, i, j, VT.u, Dim.y, 0)) / dy : (BC(u, i, j, VT.u, Dim.y, 0) - BC(u, i, j, VT.u, Dim.y, -1)) / dy;
                vDx = (u[Math.Clamp(i, 0, width - 1), Math.Clamp(j, 0, height - 1)] < 0) ? (BC(v, i, j, VT.v, Dim.x, 1) - BC(v, i, j, VT.v, Dim.x, 0)) / dx : (BC(v, i, j, VT.v, Dim.x, 0) - BC(v, i, j, VT.v, Dim.x, -1)) / dx;
                vDy = (v[Math.Clamp(i, 0, width - 1), Math.Clamp(j, 0, height - 1)] < 0) ? (BC(v, i, j, VT.v, Dim.y, 1) - BC(v, i, j, VT.v, Dim.y, 0)) / dy : (BC(v, i, j, VT.v, Dim.y, 0) - BC(v, i, j, VT.v, Dim.y, -1)) / dy;
            }//todo: add check for if value has already been calculated this timestep 
            else if (i == 0 || j == 0 || i == width-1 || j == height-1)
            {
                uDx = (u[i, j] < 0) ? (BC(u, i, j, VT.u, Dim.x, 1) - u[i, j]) / dx : (u[i, j] - BC(u, i, j, VT.u, Dim.x, -1)) / dx;
                uDy = (v[i, j] < 0) ? (BC(u, i, j, VT.u, Dim.y, 1) - u[i, j]) / dy : (u[i, j] - BC(u, i, j, VT.u, Dim.y, -1)) / dy;
                vDx = (u[i, j] < 0) ? (BC(v, i, j, VT.v, Dim.x, 1) - v[i, j]) / dx : (v[i, j] - BC(v, i, j, VT.v, Dim.x, -1)) / dx;
                vDy = (v[i, j] < 0) ? (BC(v, i, j, VT.v, Dim.y, 1) - v[i, j]) / dy : (v[i, j] - BC(v, i, j, VT.v, Dim.y, -1)) / dy;
            } else
            {
                uDx = (u[i, j] < 0) ? (u[i+1,j] - u[i, j]) / dx : (u[i, j] - u[i-1,j]) / dx;
                uDy = (v[i, j] < 0) ? (u[i,j+1] - u[i, j]) / dy : (u[i, j] - u[i,j-1]) / dy;
                vDx = (u[i, j] < 0) ? (v[i+1,j] - v[i, j]) / dx : (v[i, j] - v[i-1,j]) / dx;
                vDy = (v[i, j] < 0) ? (v[i,j+1] - v[i, j]) / dy : (v[i, j] - v[i,j-1]) / dy;
            }
            //∇*u
            divU = uDx + vDy;

            TxxA[ti, tj] = ((2f / 3f) * 0.0000186f) * divU + 2f * 0.0000186f * uDx;
            TyyA[ti, tj] = ((2f / 3f) * 0.0000186f) * divU + 2f * 0.0000186f * vDy;
            TxyA[ti, tj] = 0.0000186f * (uDy + vDx);
            tensorC[ti, tj] = true;
            if (float.IsNaN(uDx) || float.IsNaN(uDy) || float.IsNaN(vDx) || float.IsNaN(vDy))
            {
              //  Console.WriteLine(System.Runtime.CompilerServices.Unsafe.As<float, int>(ref u[0, 0]));
             //   Console.WriteLine(uDx + uDy + vDx + vDy);
              //  throw new Exception();
            }
            return;
        }

        void calcTemperature(int i, int j)
        {
            int ti = i + 1;
            int tj = j + 1;
            if (TC[ti, tj])
            {
                return;
            }
            float val;
            if ((i < 0 || i >= width || j < 0 || j >= height))
            {
                val = (BC(e, i, j, VT.E, Dim.x, 0) - 0.5f*((float)Math.Pow(BC(u, i, j, VT.u, Dim.x, 0), 2) + (float)Math.Pow(BC(v, i, j, VT.v, Dim.x, 0), 2))) / 0.718f;
            } else
            {
                val = (e[i, j] - 0.5f*((float)Math.Pow(u[i, j], 2) + (float)Math.Pow(v[i, j], 2))) / 0.718f;
            }
            T[ti, tj] = val;
            TC[ti, tj] = true;

        }

        void calcPressure(int i, int j)
        {
            int ti = i + 1;
            int tj = j + 1;
            if (pC[ti, tj])
            {
                return;
            }
            float val;
            if ((i < 0 || i >= width || j < 0 || j >= height))
            {
                val = BC(d, i, j, VT.d, Dim.x, 0) * 0.286f * T[ti, tj];
            } else
            {
                val = d[i, j] * 0.286f * T[ti, tj];
            }
            p[ti,tj] = val;
            pC[ti, tj] = true;
        }

        void calcHeatFlux(int i, int j)
        {
            int ti = i + 1;
            int tj = j + 1;
            if (qC[ti, tj])
            {
                return;
            }
            float TDx;
            float TDy;
            
            if ((i < 0 || i >= width || j < 0 || j >= height))
            {
                bool b1 = ti == 0;
                bool b2 = ti == width;
                bool b3 = tj == 0;
                bool b4 = tj == height;
                TDx = BC(u, i, j, VT.u, Dim.x, 0) < 0 ? (T[b2 ? ti : (ti + 1), tj] - T[ti, tj]) / dx : (T[ti, tj] - T[b1 ? ti : (ti - 1), tj]) / dx;
                TDy = BC(v, i, j, VT.v, Dim.y, 0) < 0 ? (T[ti, b4 ? tj : (tj + 1)] - T[ti, tj]) / dy : (T[ti, tj] - T[ti, b3 ? tj : (tj - 1)]) / dy;
            } else
            {
                TDx = u[i,j] < 0 ? (T[ti + 1, tj] - T[ti, tj]) / dx : (T[ti, tj] - T[ti - 1, tj]) / dx;
                TDy = v[i,j] < 0 ? (T[ti, tj + 1] - T[ti, tj]) / dy : (T[ti, tj] - T[ti, tj - 1]) / dy;
            }

            qx[ti, tj] = -0.02662f * TDx;
            qy[ti, tj] = -0.02662f * TDy;
            qC[ti, tj] = true;
        }

        void calcSGradient(int i, int j)
        {
            int ti = i + 1;
            int tj = j + 1;
            if (SDC[ti,tj])
            {
                return;
            }
            float sdx;
            float sdy;
            if ((i < 0 || i >= width || j < 0 || j >= height))
            {
                sdx = (u[Math.Clamp(i, 0, width - 1), Math.Clamp(j, 0, height - 1)] < 0) ? (BC(S, i, j, VT.S, Dim.x, 1) - BC(S, i, j, VT.S, Dim.x, 0)) / dx : (BC(S, i, j, VT.S, Dim.x, 0) - BC(S, i, j, VT.S, Dim.x, -1)) / dx;
                sdy = (v[Math.Clamp(i, 0, width - 1), Math.Clamp(j, 0, height - 1)] < 0) ? (BC(S, i, j, VT.S, Dim.y, 1) - BC(S, i, j, VT.S, Dim.y, 0)) / dy : (BC(S, i, j, VT.S, Dim.y, 0) - BC(S, i, j, VT.S, Dim.y, -1)) / dy;
            } else if (i == 0 || j == 0 || i == width - 1 || j == height - 1)
            {
                sdx = (u[i, j] < 0) ? (BC(S, i, j, VT.S, Dim.x, 1) - S[i, j]) / dx : (S[i, j] - BC(S, i, j, VT.S, Dim.x, -1)) / dx;
                sdy = (v[i, j] < 0) ? (BC(S, i, j, VT.S, Dim.y, 1) - S[i, j]) / dy : (S[i, j] - BC(S, i, j, VT.S, Dim.y, -1)) / dy;
            } else
            {
                sdx = (u[i, j] < 0) ? (S[i + 1, j] - S[i, j]) / dx : (S[i, j] - S[i - 1, j]) / dx;
                sdy = (v[i, j] < 0) ? (S[i, j + 1] - S[i, j]) / dy : (S[i, j] - S[i, j - 1]) / dy;
            }
            SDx[ti, tj] = sdx;
            SDy[ti, tj] = sdy;
            SDC[ti, tj] = true;
        }

        public void TimeStep(float dt)
        {
            float[,] nd = new float[width, height];
            Array.Copy(d, 0, nd, 0, width * height);
            float[,] nu = new float[width, height];
            Array.Copy(u, 0, nu, 0, width * height);
            float[,] nv = new float[width, height];
            Array.Copy(v, 0, nv, 0, width * height);
            float[,] ne = new float[width, height];
            Array.Copy(e, 0, ne, 0, width * height);
            float[,] nS = new float[width, height];
            Array.Copy(S, 0, nS, 0, width * height);

            pC = new bool[width + 2, height + 2];
            qC = new bool[width + 2, height + 2];
            TC = new bool[width + 2, height + 2];
            tensorC = new bool[width + 2, height + 2];

            for (int i = 0; i < width; i++)
            {
                for (int j = 0; j < height; j++)
                {
                    calcTemperature(i, j);
                    calcTemperature(i + 1, j);
                    calcTemperature(i - 1, j);
                    calcTemperature(i, j + 1);
                    calcTemperature(i, j - 1);

                    calcPressure(i, j);
                    calcPressure(i + 1, j);
                    calcPressure(i - 1, j);
                    calcPressure(i, j + 1);
                    calcPressure(i, j - 1);

                    calcStressTensor(i, j);
                    calcStressTensor(i - 1, j);
                    calcStressTensor(i + 1, j);
                    calcStressTensor(i, j + 1);
                    calcStressTensor(i, j - 1);

                    calcHeatFlux(i, j);
                    calcHeatFlux(i + 1, j);
                    calcHeatFlux(i - 1, j);
                    calcHeatFlux(i, j + 1);
                    calcHeatFlux(i, j - 1);

                    calcSGradient(i, j);
                    calcSGradient(i + 1, j);
                    calcSGradient(i - 1, j);
                    calcSGradient(i, j + 1);
                    calcSGradient(i, j - 1);

                    int ti = i + 1;
                    int tj = j + 1;

                    //stress dim forward/backward face (central diff)
                    float TxxXF = (TxxA[ti, tj] + TxxA[ti + 1, tj]) / 2f;
                    float TxxXB = (TxxA[ti, tj] + TxxA[ti - 1, tj]) / 2f;

                    float TxyXF = (TxyA[ti, tj] + TxyA[ti + 1, tj]) / 2f;
                    float TxyXB = (TxyA[ti, tj] + TxyA[ti - 1, tj]) / 2f;
                    float TxyYF = (TxyA[ti, tj] + TxyA[ti, tj + 1]) / 2f;
                    float TxyYB = (TxyA[ti, tj] + TxyA[ti, tj - 1]) / 2f;

                    float TyyYF = (TyyA[ti, tj] + TyyA[ti, tj + 1]) / 2f;
                    float TyyYB = (TyyA[ti, tj] + TyyA[ti, tj - 1]) / 2f;

                    /*pressure dim forward/backward face (upwind)
                    float pXF = u[i, j] >= 0 ? p[ti, tj] : p[ti + 1, tj];
                    float pXB = u[i, j] >= 0 ? p[ti - 1, tj] : p[ti, tj];
                    float pYF = v[i, j] >= 0 ? p[ti, tj] : p[ti, tj + 1];
                    float pYB = v[i, j] >= 0 ? p[ti, tj - 1] : p[ti, tj];
                    */
                    //central diff
                    float pXFC = (p[ti, tj] + p[ti + 1, tj]) /2f;
                    float pXBC = (p[ti - 1, tj] + p[ti, tj]) / 2f;
                    float pYFC = (p[ti, tj] + p[ti, tj + 1]) / 2f;
                    float pYBC = (p[ti, tj - 1] + p[ti, tj]) / 2f;

                    //heat flux dim forward/backward face (central diff)
                    float qxXF = (qx[ti, tj] + qx[ti + 1, tj]) / 2f;
                    float qxXB = (qx[ti, tj] + qx[ti - 1, tj]) / 2f;
                    float qyYF = (qy[ti, tj] + qy[ti, tj + 1]) / 2f;
                    float qyYB = (qy[ti, tj] + qy[ti, tj - 1]) / 2f;

                    //yuh
                    float dXF = CD(d, i, j, VT.d, Dim.x, true);
                    float dXB = CD(d, i, j, VT.d, Dim.x, false);
                    float dYF = CD(d, i, j, VT.d, Dim.y, true);
                    float dYB = CD(d, i, j, VT.d, Dim.x, false);
                    //central
                  //  float dXFC = CD(d, i, j, VT.d, Dim.x, true);
                   // float dXBC = CD(d, i, j, VT.d, Dim.x, false);
                  //  float dYFC = CD(d, i, j, VT.d, Dim.y, true);
                  //  float dYBC = CD(d, i, j, VT.d, Dim.x, false);

                    //upwind
                    float uXF = CD(u, i, j, VT.u, Dim.x, true);
                    float uXB = CD(u, i, j, VT.u, Dim.x, false);
                    float uYF = CD(u, i, j, VT.u, Dim.y, true);
                    float uYB = CD(u, i, j, VT.u, Dim.y, false);
                    /*central
                    float uXFC = CD(u, i, j, VT.u, Dim.x, false);
                    float uXBC = CD(u, i, j, VT.u, Dim.x, false);
                    float uYFC = CD(u, i, j, VT.u, Dim.y, true);
                    float uYBC = CD(u, i, j, VT.u, Dim.y, false);
                    */
                    //upwind
                    float vXF = CD(v, i, j, VT.v, Dim.x, true);
                    float vXB = CD(v, i, j, VT.v, Dim.x, false);
                    float vYF = CD(v, i, j, VT.v, Dim.y, true);
                    float vYB = CD(v, i, j, VT.v, Dim.y, false);
                    /*central
                    float vXFC = CD(v, i, j, VT.v, Dim.x, true);
                    float vXBC = CD(v, i, j, VT.v, Dim.x, false);
                    float vYFC = CD(v, i, j, VT.v, Dim.y, true);
                    float vYBC = CD(v, i, j, VT.v, Dim.y, false);
                    */

                    float SXF = CD(S, i, j, VT.S, Dim.x, true);
                    float SXB = CD(S, i, j, VT.S, Dim.x, false);
                    float SYF = CD(S, i, j, VT.S, Dim.y, true);
                    float SYB = CD(S, i, j, VT.S, Dim.y, false);

                    float SDxXF = (SDx[ti, tj] + SDx[ti + 1, tj]) / 2f;
                    float SDxXB = (SDx[ti, tj] + SDx[ti - 1, tj]) / 2f;

                    float SDyYF = (SDy[ti, tj] + SDy[ti, tj + 1]) / 2f;
                    float SDyYB = (SDy[ti, tj] + SDy[ti, tj - 1]) / 2f;

                    //lazy schmazy calculations for dx are left out rn
                    nd[i, j] += dt * (-(dXF * uXF - dXB * uXB) / dx - (dYF * vYF - dYB * vYB) / dy);
                    nu[i, j] += (1f / nd[i, j]) * dt * (-((dXF * uXF * uXF + pressureToggle * pXFC) - (dXB * uXB * uXB + pressureToggle * pXBC)) / dx -
                        (dYF * uYF * vYF - dYB * uYB * vYB) / dy + (TxxXF - TxxXB) / dx + (TxyYF - TxyYB) / dy);
                    nv[i, j] += (1f / nd[i, j]) * dt * (-(dXF * uXF * vXF - dXB * uXB * vXB) / dx
                        - ((dYF * vYF * vYF + pressureToggle * pYFC) - (dYB * vYB * vYB + pressureToggle * pYBC)) / dy 
                        + (TxyXF - TxyXB) / dx + (TyyYF - TyyYB) / dy);
                    ne[i, j] += (1f / nd[i, j]) * dt * (-(uXF * (dXF * FOU(e, i, j, VT.E, Dim.x, true) + pressureToggle * pXFC) - uXB * (dXB * FOU(e, i, j, VT.E, Dim.x, false) + pressureToggle * pXBC)) / dx
                     - (vYF * (dYF * FOU(e, i, j, VT.E, Dim.y, true) + pressureToggle * pYFC) - vYB * (dYB * FOU(e, i, j, VT.E, Dim.y, false) + pressureToggle * pYBC)) / dy
                     +((uXF * TxxXF + vXF * TxyXF - qxXF) - (uXB * TxxXB + vXB * TxyXB - qxXB)) / dx
                     + ((uYF * TxyYF + vYF * TyyYF - qyYF) - (uYB * TxyYB + vYB * TyyYB - qyYB)) / dy);
                    nS[i, j] += (1f / nd[i, j]) * dt * (-(dXF * uXF * SXF - dXB * uXB * SXB) / dx - (dYF * vYF * SYF - dYB * vYB * SYB) / dy + 0.05f*(SDxXF - SDxXB) / dx + 0.05f*(SDyYF - SDyYB) / dy); 

                    //+ visc terms and oressyre graduebt;
                    if (float.IsNaN(nd[i,j]) || float.IsInfinity(nd[i,j]))
                    {
                    //    nd[i, j] = 0;
                    }
                    if (float.IsNaN(nu[i, j]) || float.IsInfinity(nu[i, j]))
                    {
                    //    nu[i, j] = 0;
                    }
                    if (float.IsNaN(nv[i, j]) || float.IsInfinity(nv[i, j]))
                    {
                     //   nv[i, j] = 0;
                    }
                }
            }
            Array.Copy(nd, 0, d, 0, width * height);
            Array.Copy(nu, 0, u, 0, width * height);
            Array.Copy(nv, 0, v, 0, width * height);
            Array.Copy(ne, 0, e, 0, width * height);
            Array.Copy(nS, 0, S, 0, width * height);
        }
    }
}
