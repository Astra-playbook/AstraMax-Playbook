using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using Microsoft.Win32;

namespace AstraLive
{
    internal static class Program
    {
        [DllImport("user32.dll")]
        private static extern bool SetProcessDPIAware();

        [STAThread]
        private static void Main(string[] args)
        {
            SetProcessDPIAware();
            string folder = null;
            bool preview = false;
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == "--file" && i + 1 < args.Length) { folder = args[++i]; }
                else if (args[i] == "--preview") { preview = true; }
            }
            if (String.IsNullOrEmpty(folder)) { folder = AppDomain.CurrentDomain.BaseDirectory; }

            string mutexName = preview ? "Local\\AstraLivePreview" : "Local\\AstraLiveWallpaper";
            bool created;
            using (Mutex mutex = new Mutex(true, mutexName, out created))
            {
                if (!created) { return; }
                try
                {
                    Application.EnableVisualStyles();
                    Application.SetCompatibleTextRenderingDefault(false);
                    Application.Run(new WallpaperForm(folder, preview));
                }
                catch (Exception ex)
                {
                    Log.Write("fatal: " + ex);
                    if (preview) { MessageBox.Show(ex.Message, "Astra Live Wallpaper"); }
                }
            }
        }
    }

    internal static class Log
    {
        private static readonly object Sync = new object();

        public static void Write(string message)
        {
            try
            {
                lock (Sync)
                {
                    string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AstraMax", "Logs");
                    Directory.CreateDirectory(dir);
                    File.AppendAllText(Path.Combine(dir, "live-wallpaper.log"), DateTime.Now.ToString("s") + " " + message + "\r\n");
                }
            }
            catch { }
        }
    }

    internal sealed class GlowSpec
    {
        public float X;
        public float Y;
        public float Radius;
        public Color Color;
        public float Speed;
        public float Phase;
        public float Strength;
    }

    internal sealed class LiveConfig
    {
        public readonly List<PointF> Points = new List<PointF>();
        public readonly List<GlowSpec> Glows = new List<GlowSpec>();
        public float RootY;

        public static LiveConfig Load(string folder)
        {
            LiveConfig config = new LiveConfig();
            string path = Path.Combine(folder, "motion.json");
            if (!File.Exists(path)) { return config; }
            JavaScriptSerializer serializer = new JavaScriptSerializer();
            Dictionary<string, object> root = serializer.Deserialize<Dictionary<string, object>>(File.ReadAllText(path));
            if (root == null) { return config; }

            object rawPoints;
            if (root.TryGetValue("points", out rawPoints) && rawPoints != null)
            {
                IList points = rawPoints as IList;
                if (points != null)
                {
                    foreach (object item in points)
                    {
                        IList pair = item as IList;
                        if (pair != null && pair.Count >= 2) { config.Points.Add(new PointF(Number(pair[0]), Number(pair[1]))); }
                    }
                }
            }
            if (root.ContainsKey("rootY")) { config.RootY = Number(root["rootY"]); }
            if (config.Points.Count > 0 && config.RootY <= 0)
            {
                float max = 0;
                foreach (PointF point in config.Points) { if (point.Y > max) { max = point.Y; } }
                config.RootY = max;
            }

            object rawGlows;
            if (root.TryGetValue("glow", out rawGlows) && rawGlows != null)
            {
                IList glows = rawGlows as IList;
                if (glows == null) { return config; }
                foreach (object item in glows)
                {
                    IDictionary<string, object> glow = item as IDictionary<string, object>;
                    if (glow == null) { continue; }
                    GlowSpec spec = new GlowSpec();
                    spec.X = Number(glow.ContainsKey("x") ? glow["x"] : null);
                    spec.Y = Number(glow.ContainsKey("y") ? glow["y"] : null);
                    spec.Radius = Number(glow.ContainsKey("radius") ? glow["radius"] : null);
                    spec.Speed = Number(glow.ContainsKey("speed") ? glow["speed"] : null);
                    spec.Phase = Number(glow.ContainsKey("phase") ? glow["phase"] : null);
                    spec.Strength = Number(glow.ContainsKey("strength") ? glow["strength"] : null);
                    string color = glow.ContainsKey("color") ? Convert.ToString(glow["color"], CultureInfo.InvariantCulture) : "#ff2d55";
                    try { spec.Color = ColorTranslator.FromHtml(color); } catch { spec.Color = Color.FromArgb(255, 45, 85); }
                    if (spec.Radius <= 0) { spec.Radius = 280; }
                    if (spec.Speed <= 0) { spec.Speed = 0.9f; }
                    if (spec.Strength <= 0) { spec.Strength = 0.4f; }
                    config.Glows.Add(spec);
                }
            }
            return config;
        }

        private static float Number(object value)
        {
            if (value == null) { return 0f; }
            if (value is double) { return (float)(double)value; }
            if (value is int) { return (float)(int)value; }
            if (value is long) { return (float)(long)value; }
            if (value is decimal) { return (float)(decimal)value; }
            float parsed;
            return float.TryParse(Convert.ToString(value, CultureInfo.InvariantCulture), NumberStyles.Float, CultureInfo.InvariantCulture, out parsed) ? parsed : 0f;
        }
    }

    internal sealed class WallpaperForm : Form
    {
        private const uint SWP_NOACTIVATE = 0x0010;
        private const uint SWP_SHOWWINDOW = 0x0040;
        private static readonly IntPtr HWND_BOTTOM = new IntPtr(1);

        [DllImport("user32.dll")]
        private static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int width, int height, uint flags);
        [DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")]
        private static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern int GetClassName(IntPtr hwnd, System.Text.StringBuilder name, int max);

        [StructLayout(LayoutKind.Sequential)]
        private struct RECT { public int Left, Top, Right, Bottom; }

        private readonly string folder;
        private readonly bool preview;
        private readonly LiveConfig config;
        private readonly System.Windows.Forms.Timer timer;
        private readonly Stopwatch clock = Stopwatch.StartNew();
        private Image source;
        private Bitmap baseBitmap;
        private Bitmap hairBitmap;
        private Rectangle imageRect;
        private Rectangle hairRect;
        private Rectangle dirtyRect;
        private float rootY;
        private float tipY;
        private float sway;
        private bool paused;
        private bool attached;
        private DateTime lastAttach = DateTime.MinValue;

        public WallpaperForm(string folder, bool preview)
        {
            this.folder = folder;
            this.preview = preview;
            config = LiveConfig.Load(folder);

            Text = "Astra Live Wallpaper";
            BackColor = Color.Black;
            ForeColor = Color.White;
            DoubleBuffered = true;
            SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint | ControlStyles.OptimizedDoubleBuffer, true);
            if (preview)
            {
                FormBorderStyle = FormBorderStyle.Sizable;
                StartPosition = FormStartPosition.CenterScreen;
                ClientSize = new Size(960, 540);
                MinimumSize = new Size(480, 270);
            }
            else
            {
                FormBorderStyle = FormBorderStyle.None;
                ShowInTaskbar = false;
                StartPosition = FormStartPosition.Manual;
                Location = new Point(-32000, -32000);
                Size = new Size(100, 100);
            }

            timer = new System.Windows.Forms.Timer();
            timer.Interval = 41;
            timer.Tick += OnTick;
            SystemEvents.DisplaySettingsChanged += OnDisplayChanged;
        }

        protected override bool ShowWithoutActivation
        {
            get { return !preview; }
        }

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams parameters = base.CreateParams;
                if (!preview) { parameters.ExStyle |= 0x00000020 | 0x00000080 | 0x08000000; }
                return parameters;
            }
        }

        protected override void OnShown(EventArgs e)
        {
            base.OnShown(e);
            if (preview)
            {
                BuildLayers();
                timer.Start();
            }
            else
            {
                ClientSize = Screen.PrimaryScreen.Bounds.Size;
                BuildLayers();
                AttachToDesktop();
                timer.Start();
            }
        }

        protected override void OnResize(EventArgs e)
        {
            base.OnResize(e);
            if (IsHandleCreated && baseBitmap != null && preview) { BuildLayers(); }
        }

        private void OnDisplayChanged(object sender, EventArgs e)
        {
            if (preview || !IsHandleCreated) { return; }
            try
            {
                BeginInvoke(new Action(delegate
                {
                    Bounds = Screen.PrimaryScreen.Bounds;
                    BuildLayers();
                    AttachToDesktop();
                }));
            }
            catch { }
        }

        private void BuildLayers()
        {
            string imagePath = Path.Combine(folder, "image.png");
            if (source == null)
            {
                if (!File.Exists(imagePath)) { Log.Write("image missing: " + imagePath); return; }
                try { source = Image.FromFile(imagePath); }
                catch (Exception ex) { Log.Write("image load failed: " + ex.Message); return; }
            }
            if (baseBitmap != null) { baseBitmap.Dispose(); baseBitmap = null; }
            if (hairBitmap != null) { hairBitmap.Dispose(); hairBitmap = null; }

            int width = Math.Max(1, ClientSize.Width);
            int height = Math.Max(1, ClientSize.Height);
            baseBitmap = new Bitmap(width, height, PixelFormat.Format32bppPArgb);
            using (Graphics graphics = Graphics.FromImage(baseBitmap))
            {
                graphics.Clear(Color.Black);
                graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
                double scale = Math.Max((double)width / source.Width, (double)height / source.Height);
                int drawWidth = (int)Math.Ceiling(source.Width * scale);
                int drawHeight = (int)Math.Ceiling(source.Height * scale);
                imageRect = new Rectangle((width - drawWidth) / 2, (height - drawHeight) / 2, drawWidth, drawHeight);
                graphics.DrawImage(source, imageRect);
            }

            if (config.Points.Count < 3)
            {
                dirtyRect = ClientRectangle;
                Log.Write("no hair mask; showing static image");
                return;
            }

            float minX = float.MaxValue, minY = float.MaxValue, maxX = float.MinValue, maxY = float.MinValue;
            foreach (PointF point in config.Points)
            {
                if (point.X < minX) { minX = point.X; }
                if (point.Y < minY) { minY = point.Y; }
                if (point.X > maxX) { maxX = point.X; }
                if (point.Y > maxY) { maxY = point.Y; }
            }
            double scaleX = source.Width > 0 ? (float)imageRect.Width / source.Width : 1f;
            double scaleY = source.Height > 0 ? (float)imageRect.Height / source.Height : 1f;
            int left = Math.Max(0, (int)Math.Floor(imageRect.X + minX * scaleX) - 6);
            int top = Math.Max(0, (int)Math.Floor(imageRect.Y + minY * scaleY) - 6);
            int right = Math.Min(width, (int)Math.Ceiling(imageRect.X + maxX * scaleX) + 7);
            int bottom = Math.Min(height, (int)Math.Ceiling(imageRect.Y + maxY * scaleY) + 7);
            if (right <= left || bottom <= top) { dirtyRect = ClientRectangle; return; }
            hairRect = new Rectangle(left, top, right - left, bottom - top);
            rootY = (float)(imageRect.Y + config.RootY * scaleY);
            tipY = (float)(imageRect.Y + minY * scaleY);

            PointF[] screenPoints = new PointF[config.Points.Count];
            for (int i = 0; i < config.Points.Count; i++)
            {
                screenPoints[i] = new PointF(
                    (float)(imageRect.X + config.Points[i].X * scaleX),
                    (float)(imageRect.Y + config.Points[i].Y * scaleY));
            }

            hairBitmap = new Bitmap(hairRect.Width, hairRect.Height, PixelFormat.Format32bppPArgb);
            float span = Math.Max(1f, rootY - tipY);
            for (int py = 0; py < hairRect.Height; py++)
            {
                for (int px = 0; px < hairRect.Width; px++)
                {
                    int sx = hairRect.X + px;
                    int sy = hairRect.Y + py;
                    if (!InsidePolygon(sx, sy, screenPoints)) { continue; }
                    Color baseColor = baseBitmap.GetPixel(sx, sy);
                    float hair = Math.Max(0f, Math.Min(1f, (Math.Min(baseColor.R, Math.Min(baseColor.G, baseColor.B)) - 85) / 80f));
                    float anchor = Math.Max(0f, Math.Min(1f, (rootY - sy) / span));
                    float edge = Math.Min(px, py);
                    edge = Math.Min(edge, hairRect.Width - px - 1);
                    edge = Math.Min(edge, hairRect.Height - py - 1);
                    edge = Math.Max(0f, Math.Min(1f, edge / 5f));
                    float weight = hair * anchor * anchor * edge;
                    if (weight <= 0.01f) { continue; }
                    hairBitmap.SetPixel(px, py, Color.FromArgb((int)(255 * weight), baseColor.R, baseColor.G, baseColor.B));
                }
            }

            dirtyRect = hairRect;
            dirtyRect.Inflate(12, 12);
            foreach (GlowSpec glow in config.Glows)
            {
                Rectangle glowRect = GlowBounds(glow);
                dirtyRect = Rectangle.Union(dirtyRect, glowRect);
            }
            dirtyRect.Intersect(ClientRectangle);
            Log.Write("layers ready " + width + "x" + height + ", hair " + hairRect.Width + "x" + hairRect.Height + ", glows " + config.Glows.Count);
        }

        private Rectangle GlowBounds(GlowSpec glow)
        {
            double scale = source != null && source.Width > 0 ? (float)imageRect.Width / source.Width : 1f;
            int radius = (int)Math.Ceiling(glow.Radius * scale * 1.1);
            int x = (int)Math.Round(imageRect.X + glow.X * scale);
            int y = (int)Math.Round(imageRect.Y + glow.Y * scale);
            return new Rectangle(x - radius, y - radius, radius * 2, radius * 2);
        }

        private void AttachToDesktop()
        {
            if (Handle == IntPtr.Zero) { return; }
            Rectangle bounds = Screen.PrimaryScreen.Bounds;
            bool moved = SetWindowPos(Handle, HWND_BOTTOM, 0, 0, bounds.Width, bounds.Height,
                SWP_NOACTIVATE | SWP_SHOWWINDOW);
            attached = moved;
            lastAttach = DateTime.UtcNow;
            Log.Write(attached
                ? "pinned wallpaper window at desktop level " + bounds.Width + "x" + bounds.Height
                : "desktop window placement failed");
        }

        private void OnTick(object sender, EventArgs e)
        {
            if (!preview)
            {
                if (!attached)
                {
                    if ((DateTime.UtcNow - lastAttach).TotalSeconds > 3) { AttachToDesktop(); }
                    return;
                }
                bool nowPaused = IsFullscreenCovered();
                if (nowPaused != paused) { paused = nowPaused; Invalidate(); }
                if (paused) { return; }
            }
            float t = (float)clock.Elapsed.TotalSeconds;
            sway = (float)(Math.Sin(t * 1.25) * 3.0 + Math.Sin(t * 2.1) * 0.9);
            if (dirtyRect.Width > 0 && dirtyRect.Height > 0) { Invalidate(dirtyRect); }
            else { Invalidate(); }
        }

        private bool IsFullscreenCovered()
        {
            IntPtr foreground = GetForegroundWindow();
            if (foreground == IntPtr.Zero || foreground == Handle) { return false; }
            RECT rect;
            if (!GetWindowRect(foreground, out rect)) { return false; }
            Rectangle screen = Screen.PrimaryScreen.Bounds;
            if (rect.Left > screen.Left + 2 || rect.Top > screen.Top + 2 || rect.Right < screen.Right - 2 || rect.Bottom < screen.Bottom - 2) { return false; }
            System.Text.StringBuilder name = new System.Text.StringBuilder(128);
            GetClassName(foreground, name, name.Capacity);
            string cls = name.ToString();
            return cls != "Progman" && cls != "WorkerW" && cls != "Shell_TrayWnd";
        }

        private static bool InsidePolygon(float x, float y, PointF[] points)
        {
            bool inside = false;
            for (int i = 0, j = points.Length - 1; i < points.Length; j = i++)
            {
                float xi = points[i].X, yi = points[i].Y;
                float xj = points[j].X, yj = points[j].Y;
                if (((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) { inside = !inside; }
            }
            return inside;
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            if (baseBitmap == null) { return; }
            DrawScene(e.Graphics);
            base.OnPaint(e);
        }

        private void DrawScene(Graphics graphics)
        {
            float t = (float)clock.Elapsed.TotalSeconds;
            graphics.CompositingMode = CompositingMode.SourceOver;
            graphics.CompositingQuality = CompositingQuality.HighSpeed;
            graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
            graphics.DrawImageUnscaled(baseBitmap, 0, 0);
            DrawHair(graphics, paused ? 0f : sway);
            DrawGlows(graphics, t);
        }

        private void DrawHair(Graphics graphics, float offset)
        {
            if (hairBitmap == null) { return; }
            GraphicsState state = graphics.Save();
            float rootLocal = Math.Max(1f, rootY - hairRect.Y);
            using (Matrix matrix = new Matrix())
            {
                matrix.Translate(hairRect.X, hairRect.Y, MatrixOrder.Append);
                matrix.Translate(0, -rootLocal, MatrixOrder.Append);
                matrix.Shear(-offset / rootLocal, 0, MatrixOrder.Append);
                matrix.Translate(0, rootLocal, MatrixOrder.Append);
                graphics.Transform = matrix;
                graphics.DrawImage(hairBitmap, 0, 0);
            }
            graphics.Restore(state);
        }

        private void DrawGlows(Graphics graphics, float t)
        {
            if (source == null || config.Glows.Count == 0) { return; }
            double scale = imageRect.Width / (double)source.Width;
            graphics.CompositingMode = CompositingMode.SourceOver;
            graphics.SmoothingMode = SmoothingMode.HighSpeed;
            foreach (GlowSpec glow in config.Glows)
            {
                float pulse = 0.5f + 0.5f * (float)Math.Sin(t * glow.Speed + glow.Phase);
                float alpha = glow.Strength * (0.22f + 0.78f * pulse);
                if (paused) { alpha = glow.Strength * 0.55f; }
                float radius = (float)(glow.Radius * scale * (1.0 + 0.05 * (pulse - 0.5)));
                float x = (float)(imageRect.X + glow.X * scale);
                float y = (float)(imageRect.Y + glow.Y * scale);
                using (GraphicsPath path = new GraphicsPath())
                {
                    path.AddEllipse(x - radius, y - radius, radius * 2, radius * 2);
                    using (PathGradientBrush brush = new PathGradientBrush(path))
                    {
                        brush.CenterColor = Color.FromArgb((int)(255 * alpha), glow.Color);
                        brush.SurroundColors = new Color[] { Color.FromArgb(0, glow.Color) };
                        graphics.FillPath(brush, path);
                    }
                }
            }
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            timer.Stop();
            SystemEvents.DisplaySettingsChanged -= OnDisplayChanged;
            base.OnFormClosing(e);
        }

        protected override void Dispose(bool disposing)
        {
            if (disposing)
            {
                timer.Dispose();
                if (hairBitmap != null) { hairBitmap.Dispose(); }
                if (baseBitmap != null) { baseBitmap.Dispose(); }
                if (source != null) { source.Dispose(); }
            }
            base.Dispose(disposing);
        }
    }
}
