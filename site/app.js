(function() {
  const e = React.createElement;
  const Root = () => e('div', { className: 'card' },
    e('h1', null, 'Hello from React! ⚛️'),
    e('p', null, 'This page is served via CloudFront from a private S3 bucket (OAC).'),
    e('ul', null,
      e('li', null, 'Build time (UTC): 2025-10-24T17:59:14.781954Z'),
      e('li', null, 'User agent: ' + navigator.userAgent)
    ),
    e('button', { onClick: () => fetch('styles.css', { cache: 'no-cache' })
      .then(r => r.text())
      .then(t => alert('Fetched styles.css: ' + t.length + ' bytes'))
      .catch(err => alert('Fetch failed: ' + err)) }, 'Test fetch')
  );
  const root = ReactDOM.createRoot(document.getElementById('root'));
  root.render(e(Root));
})();
