-- Быстрый фикс: placeholder для 17 туров без фото
-- Используем красивое стоковое фото для всех пустых image_url

UPDATE tours
SET image_url = 'https://images.unsplash.com/photo-1589727138045-d52f3346d681?w=800&q=80'
WHERE image_url IS NULL OR image_url = '';

-- Проверка результата
SELECT slug, title, city, image_url
FROM tours
ORDER BY created_at DESC;