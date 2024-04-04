#iChannel0 "self"

// 光線の構造体
struct Ray{
    vec3 origin;
    vec3 direction;
};

// レイの交差点情報
struct HitInfo{
    bool isHit;
    vec4 color;
    vec3 position;
    vec3 normal;
};

// カメラの構造体
struct Camera{
    vec3 origin;
    vec3 direction;
    vec3 up;
    vec3 right;
};

// 球体
struct Sphere{
    vec3 center;
    float radius;
};

// 光源
struct Light{
    vec3 position;
    vec4 color;
};

// 無限平面
struct Plane{
    vec3 normal;
    vec3 point;
};

// 乱数生成
float rand(float x)
{
    return fract(sin(x) * 10000.0);
}

Camera getInitialCamera(){
    vec3 origin = vec3(0.0, 2.0, 0.0);
    vec3 dir = vec3(0.0, -0.6, -1.0);
    vec3 right = cross(vec3(0.0, 1.0, 0.0), dir);
    vec3 up = cross(dir, right);
    return Camera(origin, dir, up, right);
}

Ray getInitialRay(Camera cam, vec2 uv){
    vec2 offset = vec2((rand(iDate.w + iTime + uv.x + uv.y + float(iFrame)) + 1.0) / 2.0, (rand(iDate.w + iTime + uv.x + uv.y + float(iFrame)) + 1.0) / 2.0) / iResolution.y;

    // レイはフラグメントの方向に向く
    vec3 rayDir = normalize(cam.direction + (uv.x + offset.x) * cam.right + (uv.y + offset.y) * cam.up);
    return Ray(cam.origin, rayDir);
}

// レイと球体の交差判定
bool getSphereIntersectionPoint(Ray ray, Sphere sphere, out vec3 intersection){
    // 球体とベクトルの交差判定
    // https://risalc.info/src/sphere-line-intersection.html
    // D = (m, x0 - a)^2 - (||x0 - a||^2 - r^2)
    vec3 L = ray.origin - sphere.center;
    float a = dot(ray.direction, ray.direction);
    float b = 2.0 * dot(ray.direction, L);
    float c = dot(L, L) - sphere.radius * sphere.radius;
    float discriminant = b * b - 4.0 * a * c;

    if (discriminant < 0.0) {
        return false;  // 交差しない
    }

    float t1 = (-b - sqrt(discriminant)) / (2.0 * a);
    float t2 = (-b + sqrt(discriminant)) / (2.0 * a);

    float t = t1 < t2 ? t1 : t2;  // カメラに近い方の交点を選択

    if (t < 0.0) return false;  // 交点がレイの後方にある

    intersection = ray.origin + t * ray.direction;
    return true;
}

// レイと無限平面の交差判定
bool getPlaneIntersectionPoint(Ray ray, Plane plane, float minimamAngle, out vec3 intersection){
    float rad = dot(ray.direction, plane.normal);
    
    // ほぼ平行であるかを判定
    if(abs(rad) > minimamAngle){
        vec3 p = plane.point - ray.origin;
        float t = dot(p, plane.normal) / rad;
        if (t >= 0.0){
            intersection = ray.origin + ray.direction * t;
            return true;
        }
    }

    return false;
}

// チェッカー色をつくる
vec3 checkerColor(vec3 point, vec3 color1, vec3 color2, float scale) {
    float pattern = mod(floor(point.x * scale) + floor(point.z * scale), 2.0);
    return mix(color1, color2, step(0.5, pattern));
}

// ランバート反射の計算
vec4 getLambertianReflection(vec3 normal, vec3 lightDir, vec4 lightColor, vec3 intersectionPoint){
    float diff = max(dot(normal, lightDir), 0.0);   // ランバートの余弦則
    return diff * lightColor;   // 拡散反射光
}

// フォン反射の計算
vec4 getPhongSpecular(vec3 normal, vec3 lightDir, vec3 viewDir, vec4 lightColor, vec3 intersection, float shininess){
    vec4 i;
    vec3 r = reflect(lightDir, normal);
    return lightColor * pow(max(dot(r, viewDir), 0.0), shininess);
}

HitInfo checkIntersection(Ray ray, Sphere sphere, Light light, Camera cam, 
                            vec4 ambientColor, Plane plane){
    HitInfo info;
    info.isHit = false;
    info.position = vec3(0.0);
    info.normal = vec3(0.0);
    info.color = vec4(0.0);

    // 交差判定
    vec3 intersection;
    vec4 color;
    vec3 normal;

    if (getSphereIntersectionPoint(ray, sphere, intersection)){
        // 球体とベクトルの交差判定
        normal = normalize(intersection - sphere.center);
        vec3 lightDir = normalize(light.position - intersection);
        vec3 viewDir = normalize(cam.origin - intersection);

        // 球体表面の色計算
        vec4 lambertianReflection = getLambertianReflection(normal, lightDir, light.color, intersection);
        vec4 phongSpecular = getPhongSpecular(normal, -lightDir, viewDir, light.color, intersection, 10.0);
        
        // HitInfoの更新
        info.color = ambientColor + 0.7 * lambertianReflection + 0.3 * phongSpecular;
        info.position = intersection;
        info.normal = normal;
        info.isHit = true;

    } else if (getPlaneIntersectionPoint(ray, plane, 0.0001, intersection)) 
    {
        // 無限平面とレイの交差
        color = vec4(checkerColor(intersection, vec3(1.0, 1.0, 1.0), vec3(0.0, 0.0, 0.0), 1.0), 1.0);

        // HitInfoの更新
        info.color = color;
        info.position = intersection;
        info.normal = normal;
        info.isHit = true;
    }

    return info;
}

// 再帰的にレイを跳ね返らせて色を計算する
vec4 RayTracing(Ray ray, int depth, Camera cam, Light light, Sphere sphere, 
                Plane plane, vec4 ambientColor, vec4 skyColor){
    
    vec4 color = vec4(0.0);

    for (int i = 0; i < 5; i++){

        HitInfo info = checkIntersection(ray, sphere, light, cam, ambientColor, plane);

        if(info.isHit){
            vec3 reflectDir = reflect(ray.direction, info.normal);
            ray = Ray(info.position, reflectDir);

            color = mix(color, info.color, 0.3);

        }
        else {
            color = mix(color, skyColor, 0.5);
            break;
        }

        // 黒い面に当たったらもう反射させない
        if(info.color.x == 0.0){
            break;
        }
    }
    return color;
}


void mainImage(out vec4 fragColor, in vec2 fragCoord){
    vec2 uv = (fragCoord - iResolution.xy * 0.5) / iResolution.y;

    vec4 previousColor = texture(iChannel0, fragCoord / iResolution.xy);

    // 初期化
    int samples = 4;
    Camera cam = getInitialCamera();
    Light light = Light(vec3(-5.0, 10.0, 5.0), vec4(1.0, 1.0, 1.0, 1.0));   // 光源
    Sphere sphere = Sphere(vec3(0, 0.0, -3.0), 1.0);    // 球体
    Plane plane = Plane(vec3(0, 1.0, 0), vec3(0, -1.0, 0));
    vec4 ambientColor = light.color * 0.1;
    vec4 skyColor = vec4(0.8, 0.8, 1.0, 1.0);
    vec4 color = vec4(0.0);

    // レイトレーシング
    for(int i = 0; i < samples; i++){
        Ray ray = getInitialRay(cam, uv);                   // レイ
        color = color + RayTracing(ray, 0, cam, light, sphere, plane, ambientColor, skyColor);
    }
    fragColor = mix(previousColor, color / float(samples), 0.05);
}   
