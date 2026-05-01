using OpenTK.Graphics.OpenGL4;
using OpenTK.Windowing.Common;
using OpenTK.Windowing.Desktop;
using OpenTK.Windowing.GraphicsLibraryFramework;
using System.Reflection.Metadata;
using System.Xml.Linq;
using System.Numerics;
using CFDPrototype.util;
using CFDPrototype;
using System.Text;

public class Program
{
    public static void Main()
    {
        Window window = new Window(2000,1200,"Sigma");
        window.Run();
    }
}

public class Window : GameWindow
{
    struct CoordIndexPair
    {
        public int i;
        public int j;
        public int index;
        public CoordIndexPair(int i,  int j, int index)
        {
            this.i = i;
            this.j = j;
            this.index = index;
        }

        public override string ToString()
        {
            return "Index: " + index + "  i: " + i + "  j:" + j;
        }
    }
    struct DebugThing
    {
        public int f2d;

        public DebugThing(int f)
        {
            f2d = f;
        }
        
    }

    struct ShaderSimInfo
    {
        public float dx;
        public float dy;
        public float dt;
        public int mousePosX;
        public int mousePosY;
        public int screenX;
        public int screenY;
        public ShaderSimInfo(float dx, float dy, float dt, Vector2 mousePos, int screnX, int screnY)
        {
            this.dx = dx;
            this.dy = dy;
            this.dt = dt;
            mousePosX = (int)mousePos.X;
            mousePosY = (int)mousePos.Y;
            screenX = screnX;
            screenY = screnY;
        }
    }

    struct DataGroup4
    {
        float R;
        float L;
        float U;
        float D;

        public DataGroup4(float r, float l, float u, float d)
        {
            R = r;
            L = l;
            U = u;
            D = d;
        }
    }

    enum SimState
    {
        Run,
        Paused,
        Step
    }


    enum Processor
    {
        CPU,
        GPU
    }

    float[] vertices =
    {
        1f, 1f,  1, 1,
        -1f,1f,  0,1,
        -1f,-1f, 0,0,
        1f, -1f, 1, 0
    };


    int vertexBufferObject; 
    int vertexArrayObject;
    private Shader shader;
    ComputeShader computeShader;
    int textureHandle;
    int compTextureHandle;
    ShaderSimInfo ssInfo;
    Field2D[,] compShaderDataIn;
    Field2D[,] compShaderDataOut;
    DebugThing[,] compShaderDebugData;
    //byte array as its currently only a mask
    int[,] compShaderMeshData;
    Field2D sigmaa;
    int ssbo;
    int ssbo1;
    int ssbo2;
    int ssbo3;
    int ssboDebug;
    float[] textureData;
    Grid grid;
    int gWidth;
    int gHeight;
    int zuh;
    int stepTicker;
    SimState simState;
    Processor proc;
    bool debugSSBOEnabled = false;
    bool updateMesh = true;
    OpenTK.Mathematics.Vector2 prevMousePos;
    public Window(int width, int height, string title) : base(GameWindowSettings.Default, new NativeWindowSettings() { ClientSize = (width, height), Title = title })
    {
        /*Vector3[] arr = Class1.Func(700,700);
        textureData = new float[arr.Length * 3];
        StreamWriter sw = new StreamWriter("C:\\Users\\Jacob\\Downloads\\TWOBLACKHOLESFROMMATH3.txt");
        for (int i = 0; i < arr.Length; i++)
        {
            textureData[i * 3] = arr[i].X/255f; 
            textureData[i * 3 + 1] = arr[i].Y / 255f;
            textureData[i * 3 + 2] = arr[i].Z/255f;
            sw.WriteLine("[" + arr[i].X + "," + arr[i].Y + "," + arr[i].Z + "],");
        }
        sw.Close();
        */
        float[,] a = { { 5.0f, 4.0f , 3.0f}, { 9.0f, 6.0f , 1.0f} , { 7.0f, 8.0f, 2.0f} };
        Matrix sigma = new Matrix(a);
        Console.WriteLine(sigma.ToString());
        Console.WriteLine(sigma.SwapColumn(1, 3));
        textureData = new float[width * height*3];
        gWidth = 800;
        gHeight = (int)(gWidth*0.6f);
        grid = new Grid(gWidth, gHeight);
        compShaderDataIn = new Field2D[gWidth, gHeight];
        compShaderDataOut = new Field2D[gWidth, gHeight];
        compShaderMeshData = new int[gWidth, gHeight];
        if (debugSSBOEnabled)
        {
            compShaderDebugData = new DebugThing[gWidth, gHeight];
        }
        sigmaa = new Field2D(0.1f, 0.2f, 0.3f, 0.4f, 0.5f);
        grid.StoreGrid(compShaderDataIn, compShaderMeshData);
        simState = SimState.Paused;
        proc = Processor.GPU;
        zuh = 0;

        //shader sim parameters
        ssInfo = new ShaderSimInfo(0.075f*0.5f,0.075f*0.5f, 0.00005f, Vector2.Zero, width, height);

        for (int i = 0; i < gWidth; i++)
        {
            for (int j = 0; j < gHeight; j++)
            {
         //       textureData[(gWidth * j + i) * 3] = grid.u[i, j];
          //      textureData[(gWidth * j + i) * 3 + 1] = grid.v[i, j];
          //      textureData[(gWidth * j + i) * 3 + 2] = grid.d[i, j] / 2f;
            }
        }

    }
    static string FloatToBinary(float f)
    {
        StringBuilder sb = new StringBuilder();
        Byte[] ba = BitConverter.GetBytes(f);
        foreach (Byte b in ba)
            for (int i = 0; i < 8; i++)
            {
                sb.Insert(0, ((b >> i) & 1) == 1 ? "1" : "0");
            }
        string s = sb.ToString();
        string r = s.Substring(0, 1) + " " + s.Substring(1, 8) + " " + s.Substring(9); //sign exponent mantissa
        return r;
    }

    unsafe protected override void OnLoad()
    {
        base.OnLoad();

        shader = new Shader("Shaders/vert.glsl", "Shaders/frag.glsl");
        computeShader = new ComputeShader("Shaders/compute.glsl");
        textureHandle = GL.GenTexture();
        compTextureHandle = GL.GenTexture();
        GL.CreateBuffers(1, out ssbo);
        GL.CreateBuffers(1, out ssbo1);
        GL.CreateBuffers(1, out ssbo2);
        GL.CreateBuffers(1, out ssbo3);
        if (debugSSBOEnabled)
        {
            GL.CreateBuffers(1, out ssboDebug);
        }
        GL.BindBuffer(BufferTarget.ShaderStorageBuffer, ssbo);
        unsafe
        {
            GL.BufferData(BufferTarget.ShaderStorageBuffer, compShaderDataIn.Length * sizeof(Field2D) + sizeof(ShaderSimInfo), IntPtr.Zero, BufferUsageHint.DynamicCopy);
            GL.BufferSubData(BufferTarget.ShaderStorageBuffer, IntPtr.Zero, sizeof(ShaderSimInfo), ref ssInfo);
            fixed (Field2D* ptr = &compShaderDataIn[0,0]) {
                GL.BufferSubData(BufferTarget.ShaderStorageBuffer, (IntPtr)sizeof(ShaderSimInfo), compShaderDataIn.Length * sizeof(Field2D), (IntPtr)ptr);
            }
        }

        GL.BindBufferBase(BufferRangeTarget.ShaderStorageBuffer, 2, ssbo);
        GL.BindBuffer(BufferTarget.ShaderStorageBuffer, 0);

        GL.BindBuffer(BufferTarget.ShaderStorageBuffer, ssbo1);
        unsafe
        {
            fixed (Field2D* ptr = &compShaderDataOut[0,0])
            {
                GL.BufferData(BufferTarget.ShaderStorageBuffer, compShaderDataOut.Length * sizeof(Field2D), (IntPtr)ptr, BufferUsageHint.DynamicRead);
            }
        }
        GL.BindBufferBase(BufferRangeTarget.ShaderStorageBuffer, 3, ssbo1);
        GL.BindBuffer(BufferTarget.ShaderStorageBuffer, 0);

        GL.BindBuffer(BufferTarget.ShaderStorageBuffer, ssbo2);
        unsafe
        {
            fixed (int* ptr2 = &compShaderMeshData[0,0])
            {
                GL.BufferData(BufferTarget.ShaderStorageBuffer, compShaderMeshData.Length * sizeof(int), (IntPtr)ptr2, BufferUsageHint.DynamicRead);
                GL.BindBufferBase(BufferRangeTarget.ShaderStorageBuffer, 4, ssbo2);
                GL.BindBuffer(BufferTarget.ShaderStorageBuffer, 0);
            }
        }

        GL.BindBuffer(BufferTarget.ShaderStorageBuffer, ssbo3);
        unsafe
        {
            fixed (Field2D* ptr3 = &compShaderDataIn[0,0]) {
                GL.BufferData(BufferTarget.ShaderStorageBuffer, compShaderDataOut.Length * sizeof(Field2D), (IntPtr)ptr3, BufferUsageHint.DynamicRead);
            }
        }
        GL.BindBufferBase(BufferRangeTarget.ShaderStorageBuffer, 6, ssbo3);
        GL.BindBuffer(BufferTarget.ShaderStorageBuffer, 0);

        if (debugSSBOEnabled)
        {
            GL.BindBuffer(BufferTarget.ShaderStorageBuffer, ssboDebug);
            unsafe
            {
                fixed (DebugThing* ptr = &compShaderDebugData[0, 0])
                {
                    GL.BufferData(BufferTarget.ShaderStorageBuffer, compShaderDebugData.Length * sizeof(DebugThing), (IntPtr)ptr, BufferUsageHint.DynamicRead);
                }
            }
            GL.BindBufferBase(BufferRangeTarget.ShaderStorageBuffer, 5, ssboDebug);
            GL.BindBuffer(BufferTarget.ShaderStorageBuffer, 0);
        }
        
        vertexBufferObject = GL.GenBuffer();

        vertexArrayObject = GL.GenVertexArray();
        GL.BindVertexArray(vertexArrayObject);
        GL.BindBuffer(BufferTarget.ArrayBuffer, vertexBufferObject);
        GL.BufferData(BufferTarget.ArrayBuffer, vertices.Length * sizeof(float), vertices, BufferUsageHint.StaticDraw);

        GL.VertexAttribPointer(0, 2, VertexAttribPointerType.Float, false, 4 * sizeof(float), 0);
        GL.EnableVertexAttribArray(0);

        GL.EnableVertexAttribArray(1);
        GL.VertexAttribPointer(1, 2, VertexAttribPointerType.Float, false, 4 * sizeof(float), 2 * sizeof(float));

        GL.ActiveTexture(TextureUnit.Texture0);
        GL.BindTexture(TextureTarget.Texture2D, textureHandle);
        GL.UseProgram(shader.handle);
        GL.Uniform1(GL.GetUniformLocation(shader.handle, "texture1"), 1);
        GL.TexImage2D(TextureTarget.Texture2D, 0, PixelInternalFormat.Rgb32f, gWidth, gHeight, 0, PixelFormat.Rgb,PixelType.Float, textureData);
        GL.TexParameter(TextureTarget.Texture2D, TextureParameterName.TextureMinFilter, (int)TextureMinFilter.Nearest);
        GL.TexParameter(TextureTarget.Texture2D, TextureParameterName.TextureMagFilter, (int)TextureMagFilter.Nearest);
        GL.TexParameter(TextureTarget.Texture2D, TextureParameterName.TextureWrapS, (int)TextureWrapMode.ClampToEdge);
        GL.TexParameter(TextureTarget.Texture2D, TextureParameterName.TextureWrapT, (int)TextureWrapMode.ClampToEdge);

        GL.ActiveTexture(TextureUnit.Texture1);
        GL.BindTexture(TextureTarget.Texture2D, compTextureHandle);
        GL.TexImage2D(TextureTarget.Texture2D, 0, PixelInternalFormat.Rgba32f, gWidth, gHeight, 0, PixelFormat.Rgba, PixelType.Float, new IntPtr());
        GL.TexParameter(TextureTarget.Texture2D, TextureParameterName.TextureWrapS, (int)TextureWrapMode.ClampToEdge);
        GL.TexParameter(TextureTarget.Texture2D, TextureParameterName.TextureWrapT, (int)TextureWrapMode.ClampToEdge);
        GL.TexParameter(TextureTarget.Texture2D, TextureParameterName.TextureMinFilter, (int)TextureMinFilter.Nearest);
        GL.TexParameter(TextureTarget.Texture2D, TextureParameterName.TextureMagFilter, (int)TextureMagFilter.Nearest);
        GL.BindImageTexture(1, compTextureHandle, 0, false, 0, TextureAccess.ReadWrite, SizedInternalFormat.Rgba32f);

    }

    protected override void OnUnload()
    {
        base.OnUnload();
        shader.Dispose();
        computeShader.Dispose();
    }

    protected override void OnRenderFrame(FrameEventArgs e)
    {
        base.OnRenderFrame(e);
        Title = "Sigma" + (int)(MousePosition.X * ((float)gWidth / ClientSize.X)) + ", " + (int)(MousePosition.Y * ((float)gHeight / ClientSize.Y));
        GL.Clear(ClearBufferMask.ColorBufferBit);
        if (prevMousePos != MousePosition)
        {
            Field2D mouseCell = compShaderDataOut[Math.Clamp((int)(MousePosition.X * ((float)gWidth / ClientSize.X)),0,gWidth-1), Math.Clamp(gHeight-(int)(MousePosition.Y * ((float)gHeight / ClientSize.Y)),0,gHeight-1)];
            Console.WriteLine("d:" + mouseCell.d + " u:" + mouseCell.u + " v:" + mouseCell.v + " E:" + mouseCell.E);
            prevMousePos = MousePosition;
        }
        if (proc == Processor.GPU && simState != SimState.Paused)
        {
            zuh++;
            Console.WriteLine("step:" + zuh + " t:" + (zuh * ssInfo.dt).ToString("0.000000") + "                fps:" + (1 / e.Time).ToString("#.#"));
            if (simState == SimState.Step)
            {
                stepTicker--;
                if (stepTicker == 0)
                {
                    simState = SimState.Paused;
                }
            }
            ssInfo.mousePosX = (int)MousePosition.X;
            ssInfo.mousePosY = (int)MousePosition.Y;
            GL.BindBuffer(BufferTarget.ShaderStorageBuffer, ssbo);
            unsafe
            {
                fixed (void* dataPtr = &compShaderDataIn[0, 0])
                {
                    IntPtr ptr = GL.MapBufferRange(BufferTarget.ShaderStorageBuffer, (IntPtr)(sizeof(ShaderSimInfo)), compShaderDataIn.Length * sizeof(Field2D), MapBufferAccessMask.MapWriteBit);
                    System.Buffer.MemoryCopy(dataPtr, ptr.ToPointer(), compShaderDataIn.Length * sizeof(Field2D), compShaderDataIn.Length * sizeof(Field2D));
                    GL.UnmapBuffer(BufferTarget.ShaderStorageBuffer);
                }
                fixed (ShaderSimInfo* ssInfoPtr = &ssInfo)
                {
                    IntPtr ptrH = GL.MapBuffer(BufferTarget.ShaderStorageBuffer, BufferAccess.WriteOnly);
                    System.Buffer.MemoryCopy(ssInfoPtr, ptrH.ToPointer(), sizeof(ShaderSimInfo), sizeof(ShaderSimInfo));
                    GL.UnmapBuffer(BufferTarget.ShaderStorageBuffer);
                }
            }
            computeShader.Use();
            GL.DispatchCompute(gWidth, gHeight, 1);
            GL.MemoryBarrier(MemoryBarrierFlags.ShaderStorageBarrierBit);

            GL.BindBuffer(BufferTarget.ShaderStorageBuffer, ssbo1);
            IntPtr ptr1 = GL.MapBuffer(BufferTarget.ShaderStorageBuffer, BufferAccess.ReadWrite);
            unsafe
            {
                fixed (void* dataPtr = &compShaderDataOut[0, 0])
                {
                    fixed (void* dataPtr2 = &compShaderDataIn[0, 0])
                    {
                        System.Buffer.MemoryCopy(ptr1.ToPointer(), dataPtr, compShaderDataOut.Length * sizeof(Field2D), compShaderDataOut.Length * sizeof(Field2D));
                        GL.UnmapBuffer(BufferTarget.ShaderStorageBuffer);

                        GL.BindBuffer(BufferTarget.ShaderStorageBuffer, ssbo3);
                        IntPtr ptr5 = GL.MapBuffer(BufferTarget.ShaderStorageBuffer, BufferAccess.WriteOnly);
                        System.Buffer.MemoryCopy(dataPtr2, ptr5.ToPointer(), compShaderDataOut.Length * sizeof(Field2D), compShaderDataOut.Length * sizeof(Field2D));
                        GL.UnmapBuffer(BufferTarget.ShaderStorageBuffer);
                        System.Buffer.MemoryCopy(dataPtr, dataPtr2, compShaderDataOut.Length * sizeof(Field2D), compShaderDataOut.Length * sizeof(Field2D));
                    }
                }
            }

            if (updateMesh)
            {
                GL.BindBuffer(BufferTarget.ShaderStorageBuffer, ssbo2);
                unsafe
                {
                    fixed (int* ptr3 = &compShaderMeshData[0, 0])
                    {
                        IntPtr ptrH = GL.MapBuffer(BufferTarget.ShaderStorageBuffer, BufferAccess.WriteOnly);
                        System.Buffer.MemoryCopy(ptr3, ptrH.ToPointer(), compShaderMeshData.Length * sizeof(int), compShaderMeshData.Length * sizeof(int));
                        GL.UnmapBuffer(BufferTarget.ShaderStorageBuffer);
                    }
                }
                updateMesh = false;
            }

            if (debugSSBOEnabled)
            {
                GL.BindBuffer(BufferTarget.ShaderStorageBuffer, ssboDebug);
                IntPtr ptr2 = GL.MapBuffer(BufferTarget.ShaderStorageBuffer, BufferAccess.ReadWrite);
                unsafe
                {
                    fixed (void* debugDataPtr = &compShaderDebugData[0, 0])
                    {
                        System.Buffer.MemoryCopy(ptr2.ToPointer(), debugDataPtr, compShaderDebugData.Length * sizeof(DebugThing), compShaderDebugData.Length * sizeof(DebugThing));
                    }
                }
                GL.UnmapBuffer(BufferTarget.ShaderStorageBuffer);
            }
        }
        
        shader.Use();
        GL.BindVertexArray(vertexArrayObject);
        GL.ActiveTexture(TextureUnit.Texture1);
        GL.BindTexture(TextureTarget.Texture2D, compTextureHandle);
        GL.DrawArrays(PrimitiveType.TriangleFan, 0, 4);

        SwapBuffers();
    }
    protected override void OnFramebufferResize(FramebufferResizeEventArgs e)
    {
        base.OnFramebufferResize(e);

        GL.Viewport(0, 0, e.Width, e.Height);
    }
    protected override void OnUpdateFrame(FrameEventArgs e)
    {
        if (proc == Processor.CPU)
        {
            grid.TimeStep(0.0006f);
            for (int i = 0; i < gWidth; i++)
            {
                for (int j = 0; j < gHeight; j++)
                {
                    textureData[(gWidth * j + i) * 3] = (float)Math.Sqrt(grid.u[i, j] * grid.u[i, j] + grid.v[i, j] * grid.v[i, j]);
                    textureData[(gWidth * j + i) * 3 + 1] = grid.e[i, j] / 50f;
                    textureData[(gWidth * j + i) * 3 + 2] = grid.d[i, j] / 2.5f;

                    textureData[(gWidth * j + i) * 3] = grid.S[i, j];
                    textureData[(gWidth * j + i) * 3 + 1] = 0.2f;
                    textureData[(gWidth * j + i) * 3 + 2] = 1f - grid.S[i, j];
                }
            }
            // GL.TexImage2D(TextureTarget.Texture2D, 0, PixelInternalFormat.Rgb32f, gWidth, gHeight, 0, PixelFormat.Rgb, PixelType.Float, textureData);
        }
    }

    protected override void OnKeyDown(KeyboardKeyEventArgs e)
    {
        base.OnKeyDown(e);
        switch (e.Key)
        {
            case Keys.P:
                if (simState == SimState.Paused)
                {
                    simState = SimState.Run;
                } else
                {
                    simState = SimState.Paused;
                }
                break;
            case Keys.U:
                simState = SimState.Step;
                stepTicker = 1;
                break;
            case Keys.I:
                simState = SimState.Step;
                stepTicker = 10;
                break;
            case Keys.O:
                simState = SimState.Step;
                stepTicker = 50;
                break;
        }
    }
}
